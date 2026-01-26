//
//  CwlDemangleAdditionalTests.swift
//  CwlDemangleTests
//
//  Created by Matt Gallagher on 15/2/20.
//  Copyright © 2020 Matt Gallagher. All rights reserved.
//

#if SWIFT_PACKAGE
@testable import CwlDemangle
#endif

import Foundation
import XCTest

class CwlDemangleAdditionalTests: XCTestCase {
	func testUnicodeProblem() {
		let input = "_T0s14StringProtocolP10FoundationSS5IndexVADRtzrlE10componentsSaySSGqd__11separatedBy_tsAARd__lF"
		let output = "(extension in Foundation):Swift.StringProtocol< where A.Index == Swift.String.Index>.components<A where A1: Swift.StringProtocol>(separatedBy: A1) -> [Swift.String]"
		do {
			let parsed = try parseMangledSwiftSymbol(input)
			let result = parsed.print(using: SymbolPrintOptions.default.union(.synthesizeSugarOnTypes))
			XCTAssert(result == output, "Failed to demangle \(input). Got \(result), expected \(output)")
		} catch {
			XCTFail("Failed to demangle \(input). Got \(error), expected \(output)")
		}
	}
	func test_T011CryptoSwift3AESC0017sBoxstorage_wEEFc33_2FA9B7ACC72B80C564A140F8079C9914LLSays6UInt32VGSgvpWvd() {
		let input = "_T011CryptoSwift3AESC0017sBoxstorage_wEEFc33_2FA9B7ACC72B80C564A140F8079C9914LLSays6UInt32VGSgvpWvd"
		let output = "direct field offset for CryptoSwift.AES.(sBox.storage in _2FA9B7ACC72B80C564A140F8079C9914) : [Swift.UInt32]?"
		do {
			let parsed = try parseMangledSwiftSymbol(input)
			let result = parsed.print(using: SymbolPrintOptions.default.union(.synthesizeSugarOnTypes))
			XCTAssert(result == output, "Failed to demangle \(input). Got \(result), expected \(output)")
		} catch {
			XCTFail("Failed to demangle \(input). Got \(error), expected \(output)")
		}
	}
	
	func testLargeMethodNameIssueWithGraphZahl() {
		let input = "$s11rentXserver8RentXApiO5QueryC13createBooking6userId03carI09startDate03endL03lat4long16bookingConfirmed5price8discount5isNew3NIO15EventLoopFutureCyAA0G0CG10Foundation4UUIDV_AyW0L0VA_S2fSbS2dSbtF"
		
		let output = "rentXserver.RentXApi.Query.createBooking(userId: Foundation.UUID, carId: Foundation.UUID, startDate: Foundation.Date, endDate: Foundation.Date, lat: Swift.Float, long: Swift.Float, bookingConfirmed: Swift.Bool, price: Swift.Double, discount: Swift.Double, isNew: Swift.Bool) -> NIO.EventLoopFuture<rentXserver.Booking>"
		
		do {
			let parsed = try parseMangledSwiftSymbol(input)
			let result = parsed.print(using: SymbolPrintOptions.default.union(.synthesizeSugarOnTypes))
			XCTAssert(result == output, "Failed to demangle \(input). Got \(result), expected \(output)")
		} catch {
			XCTFail("Failed to demangle \(input). Got \(error), expected \(output)")
		}
	}
	
	func testIssue16() {
		let input = "$s20EagleFilerSwiftTests07EFErrorD0C00141$s20EagleFilerSwiftTests07EFErrorD0C20nsErrorRoundTripping4TestfMp_62__$test_container__function__funcnsErrorRoundTripping__throwsfMu__FnFBDlO7__testsSay7Testing4TestVGvgZyyYaYbKcfu_TQ0_"
		let output = "(1) await resume partial function for implicit closure #1 @Sendable () async throws -> () in static EagleFilerSwiftTests.EFErrorTests.$s20EagleFilerSwiftTests07EFErrorD0C20nsErrorRoundTripping4TestfMp_62__🟠$test_container__function__funcnsErrorRoundTripping__throwsfMu_.__tests.getter : [Testing.Test]"
		do {
			let parsed = try parseMangledSwiftSymbol(input)
			let result = parsed.print(using: SymbolPrintOptions.default.union(.synthesizeSugarOnTypes))
			XCTAssert(result == output, "Failed to demangle \(input). Got\n\n\(result)\n, expected\n\n\(output)")
		} catch {
			XCTFail("Failed to demangle \(input). Got \(error)")
		}
	}
    
    func testIssue18() async throws {
		 // This issue requires testing on not-the-main thread.
		 try await Task.detached {
			 let symbol = try parseMangledSwiftSymbol("_$s7SwiftUI17_Rotation3DEffectV14animatableDataAA14AnimatablePairVySdAFy12CoreGraphics7CGFloatVAFyAiFyAiFyAFyA2IGAJGGGGGvpMV")
			 print(symbol.description)
		 }.value
    }
    
    func testIssue19() throws {
        let input = "_$s10AppIntents19CameraCaptureIntentP0A7ContextAC_SETn"
        let output = "associated conformance descriptor for AppIntents.CameraCaptureIntent.AppIntents.CameraCaptureIntent.AppContext: Swift.Encodable"
        do {
            let parsed = try parseMangledSwiftSymbol(input)
            let result = parsed.print(using: SymbolPrintOptions.default.union(.synthesizeSugarOnTypes))
            XCTAssert(result == output, "Failed to demangle \(input). Got\n\n\(result)\n, expected\n\n\(output)")
        } catch {
            XCTFail("Failed to demangle \(input). Got \(error)")
        }
    }
	
	func testIssue20() throws {
		let input = "_$s10AppIntents13IndexedEntityPAA0aD0Tb"
		let output = "base conformance descriptor for AppIntents.IndexedEntity: AppIntents.AppEntity"
		do {
			 let parsed = try parseMangledSwiftSymbol(input)
			 let result = parsed.print(using: SymbolPrintOptions.default.union(.synthesizeSugarOnTypes))
			 XCTAssert(result == output, "Failed to demangle \(input). Got\n\n\(result)\n, expected\n\n\(output)")
		} catch {
			 XCTFail("Failed to demangle \(input). Got \(error)")
		}
	}

	// MARK: - Performance Tests

	/// Test for deeply nested SwiftUI generic types that cause extreme slowness
	/// This symbol is 1120 chars and produces 142,066 tree nodes, taking ~40 seconds
	/// Native swift-demangle handles this in ~20ms
	func testPerformanceDeeplyNestedSwiftUIType() throws {
		let input = "_$s7SwiftUI6HStackVyAA7ForEachVySay7SafeApp12GptWidgetRSOV5BlockVGSiAA15ModifiedContentVyAA012_ConditionalM0VyAOyAA7AnyViewVAMyAMyAOyAMyAOyAMyAOyAMyAOyAMyAMyAMyAMyAMyAA6VStackVyAA05TupleP0VyAMyAMyASyAUyAA0P0P0fB0E10typographyyQrs7KeyPathCyAX0F12TypographiesVAX0F10TypographyVGFQOyAMyAA4TextVAA012_EnvironmentT15WritingModifierVySiSgGG_Qo__AMyAwXEAYyQrA4_FQOyA6__Qo_AA14_OpacityEffectVGtGGAA14_PaddingLayoutVGAA19_BackgroundModifierVyAX0hi10BackgroundP0VGG_AMyAMyAA06_ShapeP0VyAA9RectangleVAA5ColorVGAA12_FrameLayoutVGA20_GAMyAMyASyAEySaySi6offset_AH12OrganizationV7elementtGSiAOyAMyAOyAMyAOyAMyAOyAMyAMyAMyAMyAF012OrganizationP033_FC87C9A3FA42E825B2D3403C97F07AECLLVAA01_M13ShapeModifierVyA31_GGA49_GAF0hi5SheetP8Modifier33_D7B757BB09A9C38BAE0FA4E0A0E02DF5LLVyA50_GGA8_ySSSgGGA56_GA58_GA60_GA58_GA62_GA58_GA64_GGGAA16_FlexFrameLayoutVGA20_GtGGAA11_ClipEffectVyAA16RoundedRectangleVGGA23_yAOyAOyAMyAX12OutlinedCardVAA22_MatchedGeometryEffectVySSGGAMyA86_A85_GGA82_GGGA49_GA54_yA91_GGA58_GA94_GA58_GA96_GA58_GA98_GA58_GA100_GA20_GA36_GGA103_GAF011SelfControlhI9Appearing33_426F1EC575A3E7C9A47E01FB3102A0ECLLVGGGACyxGAavAWL"

		// First just verify parsing works
		let parsed = try parseMangledSwiftSymbol(input)
		XCTAssertEqual(parsed.nodeCount, 142066, "Expected 142066 nodes in the tree")

		// Time the description generation
		let startTime = Date()
		let description = parsed.description
		let elapsed = Date().timeIntervalSince(startTime)

		print("DEBUG: Demangling took \(elapsed)s, output length: \(description.count)")

		// This should complete in under 1 second (native swift-demangle does it in 20ms)
		// Currently it takes ~40 seconds
		XCTAssertLessThan(elapsed, 1.0, "Demangling deeply nested type took \(elapsed)s, expected < 1s")
	}

	// MARK: - JSON Encoding Tests

	/// Test that SwiftSymbolResult JSON encoding works correctly for deeply nested types
	func testJSONEncodingDeeplyNestedType() throws {
		let input = "_$s7SwiftUI6HStackVyAA7ForEachVySay7SafeApp12GptWidgetRSOV5BlockVGSiAA15ModifiedContentVyAA012_ConditionalM0VyAOyAA7AnyViewVAMyAMyAOyAMyAOyAMyAOyAMyAOyAMyAMyAMyAMyAMyAA6VStackVyAA05TupleP0VyAMyAMyASyAUyAA0P0P0fB0E10typographyyQrs7KeyPathCyAX0F12TypographiesVAX0F10TypographyVGFQOyAMyAA4TextVAA012_EnvironmentT15WritingModifierVySiSgGG_Qo__AMyAwXEAYyQrA4_FQOyA6__Qo_AA14_OpacityEffectVGtGGAA14_PaddingLayoutVGAA19_BackgroundModifierVyAX0hi10BackgroundP0VGG_AMyAMyAA06_ShapeP0VyAA9RectangleVAA5ColorVGAA12_FrameLayoutVGA20_GAMyAMyASyAEySaySi6offset_AH12OrganizationV7elementtGSiAOyAMyAOyAMyAOyAMyAOyAMyAMyAMyAMyAF012OrganizationP033_FC87C9A3FA42E825B2D3403C97F07AECLLVAA01_M13ShapeModifierVyA31_GGA49_GAF0hi5SheetP8Modifier33_D7B757BB09A9C38BAE0FA4E0A0E02DF5LLVyA50_GGA8_ySSSgGGA56_GA58_GA60_GA58_GA62_GA58_GA64_GGGAA16_FlexFrameLayoutVGA20_GtGGAA11_ClipEffectVyAA16RoundedRectangleVGGA23_yAOyAOyAMyAX12OutlinedCardVAA22_MatchedGeometryEffectVySSGGAMyA86_A85_GGA82_GGGA49_GA54_yA91_GGA58_GA94_GA58_GA96_GA58_GA98_GA58_GA100_GA20_GA36_GGA103_GAF011SelfControlhI9Appearing33_426F1EC575A3E7C9A47E01FB3102A0ECLLVGGGACyxGAavAWL"

		let parsed = try parseMangledSwiftSymbol(input)
		let result = SwiftSymbolResult(symbol: parsed, mangled: input)

		// Encode to JSON
		let encoder = JSONEncoder()
		let jsonData = try encoder.encode(result)

		// Verify JSON can be parsed
		let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]

		// Verify all expected fields have correct values
		XCTAssertEqual(jsonObject["identifier"] as? String, "View")
		XCTAssertEqual(jsonObject["module"] as? String, "SwiftUI")
		XCTAssertEqual(jsonObject["type"] as? String, "View")
		XCTAssertEqual(jsonObject["typeName"] as? String, "View")
		XCTAssertEqual(jsonObject["name"] as? String, "View")
		XCTAssertEqual(jsonObject["mangled"] as? String, input)

		// testName should be empty array for this symbol (it's a lazy protocol witness table cache variable)
		let testName = jsonObject["testName"] as? [String]
		XCTAssertEqual(testName, [], "testName should be empty array for protocol witness table cache variable")

		// Verify description contains expected content
		let description = jsonObject["description"] as? String
		XCTAssertNotNil(description)
		XCTAssertGreaterThan(description?.count ?? 0, 100000, "Description should be long for this deeply nested type")
		XCTAssertTrue(description?.contains("lazy protocol witness table cache variable") ?? false)
		XCTAssertTrue(description?.contains("SwiftUI.HStack") ?? false)
		XCTAssertTrue(description?.contains("SwiftUI.ForEach") ?? false)
	}

	/// Test JSON encoding for a simple function symbol
	func testJSONEncodingSimpleFunction() throws {
		let input = "$s4main3fooSSyF"  // main.foo() -> String

		let parsed = try parseMangledSwiftSymbol(input)
		let result = SwiftSymbolResult(symbol: parsed, mangled: input)

		let encoder = JSONEncoder()
		let jsonData = try encoder.encode(result)
		let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]

		// Verify all fields have expected values
		XCTAssertEqual(jsonObject["identifier"] as? String, "foo")
		XCTAssertEqual(jsonObject["name"] as? String, "foo")
		XCTAssertEqual(jsonObject["module"] as? String, "main")
		XCTAssertEqual(jsonObject["type"] as? String, "String")
		XCTAssertEqual(jsonObject["typeName"] as? String, "String")
		XCTAssertEqual(jsonObject["mangled"] as? String, input)
		XCTAssertEqual(jsonObject["description"] as? String, "main.foo() -> Swift.String")

		// testName should contain module and function name
		let testName = jsonObject["testName"] as? [String]
		XCTAssertEqual(testName, ["main", "foo"])
	}

	/// Minimal reproduction: just test the printing step
	func testPerformancePrintingOnly() throws {
		let input = "_$s7SwiftUI6HStackVyAA7ForEachVySay7SafeApp12GptWidgetRSOV5BlockVGSiAA15ModifiedContentVyAA012_ConditionalM0VyAOyAA7AnyViewVAMyAMyAOyAMyAOyAMyAOyAMyAOyAMyAMyAMyAMyAMyAA6VStackVyAA05TupleP0VyAMyAMyASyAUyAA0P0P0fB0E10typographyyQrs7KeyPathCyAX0F12TypographiesVAX0F10TypographyVGFQOyAMyAA4TextVAA012_EnvironmentT15WritingModifierVySiSgGG_Qo__AMyAwXEAYyQrA4_FQOyA6__Qo_AA14_OpacityEffectVGtGGAA14_PaddingLayoutVGAA19_BackgroundModifierVyAX0hi10BackgroundP0VGG_AMyAMyAA06_ShapeP0VyAA9RectangleVAA5ColorVGAA12_FrameLayoutVGA20_GAMyAMyASyAEySaySi6offset_AH12OrganizationV7elementtGSiAOyAMyAOyAMyAOyAMyAOyAMyAMyAMyAMyAF012OrganizationP033_FC87C9A3FA42E825B2D3403C97F07AECLLVAA01_M13ShapeModifierVyA31_GGA49_GAF0hi5SheetP8Modifier33_D7B757BB09A9C38BAE0FA4E0A0E02DF5LLVyA50_GGA8_ySSSgGGA56_GA58_GA60_GA58_GA62_GA58_GA64_GGGAA16_FlexFrameLayoutVGA20_GtGGAA11_ClipEffectVyAA16RoundedRectangleVGGA23_yAOyAOyAMyAX12OutlinedCardVAA22_MatchedGeometryEffectVySSGGAMyA86_A85_GGA82_GGGA49_GA54_yA91_GGA58_GA94_GA58_GA96_GA58_GA98_GA58_GA100_GA20_GA36_GGA103_GAF011SelfControlhI9Appearing33_426F1EC575A3E7C9A47E01FB3102A0ECLLVGGGACyxGAavAWL"

		let parsed = try parseMangledSwiftSymbol(input)

		// Test with empty options (no qualifyEntities)
		let emptyOptionsStart = Date()
		let emptyResult = parsed.print(using: [])
		let emptyElapsed = Date().timeIntervalSince(emptyOptionsStart)
		print("DEBUG: Empty options took \(emptyElapsed)s, output length: \(emptyResult.count)")

		// Test with default options
		let defaultOptionsStart = Date()
		let defaultResult = parsed.print(using: .default)
		let defaultElapsed = Date().timeIntervalSince(defaultOptionsStart)
		print("DEBUG: Default options took \(defaultElapsed)s, output length: \(defaultResult.count)")

		// Both should be fast
		XCTAssertLessThan(emptyElapsed, 1.0, "Empty options printing took \(emptyElapsed)s")
		XCTAssertLessThan(defaultElapsed, 1.0, "Default options printing took \(defaultElapsed)s")
	}
}
