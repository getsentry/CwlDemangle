//
//  main.swift
//  CwlDemangle
//
//  Created by Matt Gallagher on 2016/04/30.
//  Copyright © 2016 Matt Gallagher. All rights reserved.
//
//  Licensed under Apache License v2.0 with Runtime Library Exception
//
//  See http://swift.org/LICENSE.txt for license information
//  See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

import Foundation
import ArgumentParser
import CwlDemangle

// MARK: - CLI Structure

struct DemangleCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "demangle",
        abstract: "A Swift symbol demangler",
        version: "1.0.0",
        subcommands: [SingleCommand.self, BatchCommand.self, TestCommand.self]
    )
}

// MARK: - Single Symbol Demangling

struct SingleCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "single",
        abstract: "Demangle a single Swift symbol"
    )

    @Argument(help: "The mangled Swift symbol to demangle")
    var symbol: String

    @Flag(name: .long, help: "Output result in JSON format")
    var json = false

    @Flag(name: .long, help: "Treat input as a type rather than a symbol")
    var isType = false

    @Option(name: .long, help: "Custom print options (comma-separated)")
    var options: String?

    func run() throws {
        do {
            let swiftSymbol = try parseMangledSwiftSymbol(symbol, isType: isType)

            let printOptions = parsePrintOptions(options)
            let result = swiftSymbol.print(using: printOptions)

            if json {
                let jsonData = try JSONEncoder().encode(SwiftSymbolResult(symbol: swiftSymbol, mangled: symbol))
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    print(jsonString)
                }
            } else {
                print(result)
            }
        } catch {
            if json {
                let errorResult: [String: Any] = [
                    "error": error.localizedDescription,
                    "input": symbol,
                    "isType": isType
                ]
                let jsonData = try JSONSerialization.data(withJSONObject: errorResult, options: .prettyPrinted)
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    print(jsonString)
                }
            } else {
                print("Error: \(error.localizedDescription)")
            }
            throw ExitCode.failure
        }
    }
}

// MARK: - Batch Processing

struct BatchResult: Encodable {
    struct Error: Encodable {
        let input: String
        let error: String
    }

    let results: [SwiftSymbolResult]
    let errors: [Error]
}

struct SummaryBatchResult: Encodable {
    let results: [SwiftSymbolSummaryResult]
    let errors: [BatchResult.Error]
}

enum BatchJSONOutput: EnumerableFlag {
    case json
    case jsonSummary

    static func help(for value: Self) -> ArgumentHelp? {
        switch value {
        case .json:
            return "Output results in JSON format"
        case .jsonSummary:
            return "Output module, typeName, testName, and mangled fields as JSON"
        }
    }
}

struct BatchCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "batch",
        abstract: "Demangle multiple Swift symbols from input"
    )

    @Option(name: .shortAndLong, help: "Input file (defaults to stdin)")
    var input: String?

    @Option(name: .shortAndLong, help: "Output file (defaults to stdout)")
    var output: String?

    @Flag var jsonOutput: BatchJSONOutput?

    @Flag(name: .long, help: "Treat inputs as types rather than symbols")
    var isType = false

    @Option(name: .long, help: "Custom print options (comma-separated)")
    var options: String?

    @Flag(name: .long, help: "Continue processing on errors")
    var continueOnError = false

    func run() throws {
        let printOptions = parsePrintOptions(options)
        var results: [SwiftSymbolResult] = []
        var summaryResults: [SwiftSymbolSummaryResult] = []
        var errors: [BatchResult.Error] = []
        var errorCount = 0
        var successCount = 0

        let inputContent: String
        if let inputFile = input {
            inputContent = try String(contentsOfFile: inputFile, encoding: .utf8)
        } else {
            inputContent = String(data: FileHandle.standardInput.readDataToEndOfFile(), encoding: .utf8) ?? ""
        }

        let lines = inputContent
            .split(whereSeparator: \.isNewline)
            .lazy
            .compactMap { line -> String? in
                let trimmedLine = line.trimmingCharacters(in: .whitespaces)
                return trimmedLine.isEmpty ? nil : trimmedLine
            }

        for (index, trimmedLine) in lines.enumerated() {
            do {
                let swiftSymbol = try parseMangledSwiftSymbol(trimmedLine, isType: isType)
                successCount += 1

                switch jsonOutput {
                case .some(.json):
                    results.append(SwiftSymbolResult(symbol: swiftSymbol, mangled: trimmedLine))
                case .some(.jsonSummary):
                    summaryResults.append(SwiftSymbolSummaryResult(symbol: swiftSymbol, mangled: trimmedLine))
                case .none:
                    let result = swiftSymbol.print(using: printOptions)
                    print("\(trimmedLine) -> \(result)")
                }
            } catch {
                errorCount += 1

                if jsonOutput != nil {
                    errors.append(BatchResult.Error(input: trimmedLine, error: error.localizedDescription))
                } else {
                    print("Error on line \(index + 1): \(error.localizedDescription)")
                    if !continueOnError {
                        throw ExitCode.failure
                    }
                }
            }
        }

        if let jsonOutput = jsonOutput {
            let jsonData: Data
            switch jsonOutput {
            case .json:
                let batchResult = BatchResult(results: results, errors: errors)
                jsonData = try JSONEncoder().encode(batchResult)
            case .jsonSummary:
                let batchResult = SummaryBatchResult(results: summaryResults, errors: errors)
                jsonData = try JSONEncoder().encode(batchResult)
            }
            let jsonString = String(data: jsonData, encoding: .utf8) ?? ""

            if let outputFile = output {
                try jsonString.write(toFile: outputFile, atomically: true, encoding: .utf8)
            } else {
                print(jsonString)
            }
        } else {
            print("\nSummary: \(successCount) successful, \(errorCount) errors")
        }

        if errorCount > 0 && !continueOnError {
            throw ExitCode.failure
        }
    }
}

// MARK: - Test Command

struct TestCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "test",
        abstract: "Run built-in tests using manglings.txt"
    )

    @Flag(name: .long, help: "Output results in JSON format")
    var json = false

    @Flag(name: .long, help: "Generate XCTest cases")
    var generateTests = false

    @Flag(name: .long, help: "Run performance test")
    var performance = false

    func run() throws {
        let manglings = readManglings()
        var results: [SwiftSymbol] = []
        var errors: [[String: Any]] = []
        var errorCount = 0
        var successCount = 0

        if generateTests {
            generateTestCases(manglings)
            return
        }

        if performance {
            demanglePerformanceTest(manglings)
            return
        }

        for mangling in manglings {
            do {
                let swiftSymbol = try parseMangledSwiftSymbol(mangling.input)
                let result = swiftSymbol.print(using: SymbolPrintOptions.default.union(.synthesizeSugarOnTypes))

                let success = result == mangling.output
                if success {
                    successCount += 1
                } else {
                    errorCount += 1
                }

                if json {
                    results.append(swiftSymbol)
                } else {
                    if success {
                        print("✓ \(mangling.input) -> \(result)")
                    } else {
                        print("✗ \(mangling.input)")
                        print("  Expected: \(mangling.output)")
                        print("  Got:      \(result)")
                    }
                }
            } catch {
                errorCount += 1
                if json {
                    errors.append([
                        "input": mangling.input,
                        "expected": mangling.output,
                        "error": error.localizedDescription
                    ])
                } else {
                    print("✗ \(mangling.input) - Error: \(error.localizedDescription)")
                }
            }
        }

        if json {
            let jsonResult: [String: Any] = [
                "summary": [
                    "total": manglings.count,
                    "successful": successCount,
                    "errors": errorCount
                ],
                "results": results,
                "errors": errors
            ]

            let jsonData = try JSONSerialization.data(withJSONObject: jsonResult, options: .prettyPrinted)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print(jsonString)
            }
        } else {
            print("\nTest Summary: \(successCount) successful, \(errorCount) errors")
        }

        if errorCount > 0 {
            throw ExitCode.failure
        }
    }
}

// MARK: - Helper Functions

func parsePrintOptions(_ optionsString: String?) -> SymbolPrintOptions {
    guard let optionsString = optionsString else {
        return .default
    }

    var options = SymbolPrintOptions()
    let optionNames = optionsString.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }

    for optionName in optionNames {
        switch optionName.lowercased() {
        case "synthesizesugarontypes":
            options.insert(.synthesizeSugarOnTypes)
        case "displaydebuggergeneratedmodule":
            options.insert(.displayDebuggerGeneratedModule)
        case "qualifyentities":
            options.insert(.qualifyEntities)
        case "displayextensioncontexts":
            options.insert(.displayExtensionContexts)
        case "displayunmangledsuffix":
            options.insert(.displayUnmangledSuffix)
        case "displaymodulenames":
            options.insert(.displayModuleNames)
        case "displaygenericspecializations":
            options.insert(.displayGenericSpecializations)
        case "displayprotocolconformances":
            options.insert(.displayProtocolConformances)
        case "displaywhereclauses":
            options.insert(.displayWhereClauses)
        case "displayentitytypes":
            options.insert(.displayEntityTypes)
        case "shortenpartialapply":
            options.insert(.shortenPartialApply)
        case "shortenthunk":
            options.insert(.shortenThunk)
        case "shortenvaluewitness":
            options.insert(.shortenValueWitness)
        case "shortenarchetype":
            options.insert(.shortenArchetype)
        case "showprivatediscriminators":
            options.insert(.showPrivateDiscriminators)
        case "showfunctionargumenttypes":
            options.insert(.showFunctionArgumentTypes)
        case "showasyncresumepartial":
            options.insert(.showAsyncResumePartial)
        case "displaystdlibmodule":
            options.insert(.displayStdlibModule)
        case "displayobjcmodule":
            options.insert(.displayObjCModule)
        case "printfortypename":
            options.insert(.printForTypeName)
        case "showclosuresignature":
            options.insert(.showClosureSignature)
        case "simplified":
            options = .simplified
        default:
            print("Warning: Unknown print option '\(optionName)'")
        }
    }

    return options
}

struct Mangling {
    let input: String
    let output: String

    init(input: String, output: String) {
        if input.starts(with: "__") {
            self.input = String(input.dropFirst())
        } else {
            self.input = input
        }
        if output.starts(with: "{"), let endBrace = output.firstIndex(where: { $0 == "}" }), let space = output.index(endBrace, offsetBy: 2, limitedBy: output.endIndex) {
            self.output = String(output[space...])
        } else {
            self.output = output
        }
    }
}

func readManglings() -> [Mangling] {
    do {
        let input = try String(contentsOfFile: "./CwlDemangle_CwlDemangleTool.bundle/Contents/Resources/manglings.txt", encoding: String.Encoding.utf8)
        let lines = input.components(separatedBy: "\n").filter { !$0.isEmpty }
        return try lines.compactMap { i -> Mangling? in
            let components = i.components(separatedBy: " ---> ")
            if components.count != 2 {
                if i.components(separatedBy: " --> ").count == 2 || i.components(separatedBy: " -> ").count >= 2 {
                    return nil
                }
                enum InputError: Error { case unableToSplitLine(String) }
                throw InputError.unableToSplitLine(i)
            }
            return Mangling(input: components[0].trimmingCharacters(in: .whitespaces), output: components[1].trimmingCharacters(in: .whitespaces))
        }
    } catch {
        fatalError("Error reading manglings.txt file: \(error)")
    }
}

func generateTestCases(_ manglings: [Mangling]) {
    var existing = Set<String>()
    for mangling in manglings {
        guard existing.contains(mangling.input) == false else { continue }
        existing.insert(mangling.input)
        if mangling.input == mangling.output {
            print("""
                func test\(mangling.input.replacingOccurrences(of: ".", with: "dot").replacingOccurrences(of: "@", with: "at"))() {
                    let input = "\(mangling.input)"
                    do {
                        let demangled = try parseMangledSwiftSymbol(input).description
                        XCTFail("Invalid input \\(input) should throw an error, instead returned \\(demangled)")
                    } catch {
                    }
                }
                """)
        } else {
            print("""
                func test\(mangling.input.replacingOccurrences(of: ".", with: "dot").replacingOccurrences(of: "@", with: "at"))() {
                    let input = "\(mangling.input)"
                    let output = "\(mangling.output.replacingOccurrences(of: "\"", with: "\\\""))"
                    do {
                        let parsed = try parseMangledSwiftSymbol(input)
                        let result = parsed.print(using: SymbolPrintOptions.default.union(.synthesizeSugarOnTypes))
                        XCTAssert(result == output, "Failed to demangle \\(input).\\nGot\\n    \\(result)\\nexpected\\n    \\(output)")
                    } catch {
                        XCTFail("Failed to demangle \\(input). Got \\(error), expected \\(output)")
                    }
                }
                """)
        }
    }
}

func demanglePerformanceTest(_ manglings: [Mangling]) {
    for mangling in manglings {
        for _ in 0..<10000 {
            _ = try? parseMangledSwiftSymbol(mangling.input).description
        }
    }
}

// MARK: - Main Entry Point

DemangleCommand.main()

