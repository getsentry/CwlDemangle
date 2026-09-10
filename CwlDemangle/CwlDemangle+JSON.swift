import Foundation

public struct SwiftSymbolResult: Encodable {
  enum CodingKeys: String, CodingKey {
    case name
    case type
    case identifier
    case module
    case testName
    case typeName
    case description
    case mangled
  }

  let symbol: SwiftSymbol
  let mangled: String

  public init(symbol: SwiftSymbol, mangled: String) {
    self.symbol = symbol
    self.mangled = mangled
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(symbol.identifier, forKey: .name)
    try container.encode(symbol.typeName, forKey: .type)
    try container.encode(symbol.identifier, forKey: .identifier)
    try container.encode(symbol.module, forKey: .module)
    try container.encode(symbol.testName, forKey: .testName)
    try container.encode(symbol.typeName, forKey: .typeName)
    try container.encode(symbol.description, forKey: .description)
    try container.encode(mangled, forKey: .mangled)
  }
}

public struct SwiftSymbolSummaryResult: Encodable {
  enum CodingKeys: String, CodingKey {
    case module
    case testName
    case typeName
    case mangled
  }

  let module: String?
  let testName: [String]
  let typeName: String?
  let mangled: String

  public init(symbol: SwiftSymbol, mangled: String) {
    self.module = symbol.module
    self.testName = symbol.testName
    self.typeName = symbol.typeName
    self.mangled = mangled
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(module, forKey: .module)
    try container.encode(testName, forKey: .testName)
    try container.encode(typeName, forKey: .typeName)
    try container.encode(mangled, forKey: .mangled)
  }
}

extension SwiftSymbol: Hashable {
  public static func == (lhs: SwiftSymbol, rhs: SwiftSymbol) -> Bool {
    lhs.description == rhs.description
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(description)
  }
}

extension SwiftSymbol {
  var identifier: String? {
    var queue = [SwiftSymbol]()
    queue.append(self)
    while !queue.isEmpty {
      let item = queue.removeFirst()
      switch item.kind {
      case .identifier:
        switch item.contents {
        case .none, .index:
          return nil
        case .name(let name):
          return name
        }
      default:
        queue.append(contentsOf: item.children)
      }
    }
    return nil
  }

  var testName: [String] {
    switch self.kind {
    case .global:
      for child in children {
        let result = child.testName
        if result.count > 0 {
          return result
        }
      }
      return []
    case .module, .identifier:
      switch contents {
      case .none, .index:
        return []
      case .name(let name):
        return [name]
      }
    case .lazyProtocolWitnessTableAccessor, .protocolWitnessTableAccessor:
      return children[0].testName
    case .baseWitnessTableAccessor:
      return children[0].testName
    case .boundGenericClass:
      return children[0].testName
    case .protocolConformance:
      return children[0].testName
    case .protocolWitness:
      let conformingFunction = children[1]
      return children[0].testName + ((conformingFunction.identifier.map { [$0] }) ?? [])
    case .privateDeclName:
      if children.count >= 2 {
        return children[1].testName
      } else {
        // An initializer doesn't have a name so it could be a private declaration with only one child element
        return []
      }
    case .extension:
      // First child contains the module this is declared in, more than 2 children can be for generic requirement
      if children.count >= 2 {
        return children[1].testName
      } else {
        preconditionFailure("Invalid extension")
      }
    case .iVarDestroyer:
      return firstComponent(appending: "ivar_destroyer")
    case .deallocator:
      return firstComponent(appending: "deallocator")
    case .initializer:
      // This is used for variable initializers like "variable initialization expression of Lottie.ShapeNode.isEnabled : Swift.Bool ["Lottie", "ShapeNode", "isEnabled", "init"]"
      return firstComponent(appending: "init")
    case .variable:
      return children.filter { $0.kind != .type }.flatMap { $0.testName }
    case .explicitClosure, .implicitClosure:
      if children.count >= 1 {
        return children[0].testName
      } else {
        return []
      }
    case .defaultArgumentInitializer:
      return children.first?.testName ?? []
    case .typeAlias, .protocol, .enum, .structure, .class:
      return children.flatMap { $0.testName }
    case .function:
      if children.count >= 3, children[2].kind == .labelList,
        let functionName = children[1].testName.first
      {
        let typeName = children[0].testName
        let argumentLabels = children[2].children.flatMap { $0.testName }
        if argumentLabels.isEmpty {
          return typeName + [functionName]
        } else {
          return typeName + [functionName + "(\(argumentLabels.joined(separator: ",")))"]
        }
      }
      return children.flatMap { $0.testName }
    case .constructor, .allocator:
      if children.count >= 2, children[1].kind == .labelList {
        let typeName = children[0].testName
        let argumentLabels = children[1].children.flatMap { $0.testName }
        if argumentLabels.isEmpty {
          return typeName + ["init"]
        } else {
          return typeName + ["init" + "(\(argumentLabels.joined(separator: ",")))"]
        }
      }
      return children.flatMap { $0.testName }
    case .typeMetadataAccessFunction:
      return firstComponent(appending: "typeMetadataAccess")
    case .typeMetadataCompletionFunction:
      return firstComponent(appending: "typeMetadataCompletion")
    case .outlinedDestroy:
      return firstComponent(appending: "outlined destory")
    case .outlinedRelease:
      return firstComponent(appending: "outlined release")
    case .outlinedRetain:
      return firstComponent(appending: "outlined retain")
    case .outlinedInitializeWithCopy, .outlinedInitializeWithTake:
      return firstComponent(appending: "outlined init")
    case .outlinedAssignWithCopy, .outlinedAssignWithTake:
      return firstComponent(appending: "outlined assign")
    case .getter:
      return firstComponent(appending: "getter")
    case .setter:
      return firstComponent(appending: "setter")
    case .didSet:
      return firstComponent(appending: "didset")
    case .willSet:
      return firstComponent(appending: "willset")
    case .unsafeMutableAddressor:
      return firstComponent(appending: "addressor")
    case .objCMetadataUpdateFunction:
      return firstComponent(appending: "metadata update")
    case .destructor:
      return firstComponent(appending: "deinit")
    case .modifyAccessor:
      return children.flatMap { $0.testName }
    case .partialApplyForwarder, .partialApplyObjCForwarder:
      return children.flatMap { $0.testName }
    case .type:
      return children.flatMap { $0.testName }
    case .valueWitness:
      return firstComponent(appending: "value witness")
    case .static:
      return children.flatMap { $0.testName }
    case .typeMangling:
      return children.flatMap { $0.testName }
    default:
      return []
    }
  }

  func firstComponent(appending suffix: String) -> [String] {
    if let result = children.first?.testName {
      return result + [suffix]
    }
    return []
  }

  var module: String? {
    var genericSpecializationType: String?
    var queue = [SwiftSymbol]()
    queue.append(self)
    let moduleOrSpecialization: (String) -> String = { module in
      if let generic = genericSpecializationType, module == "Swift" {
        return generic
      }
      return module
    }
    while !queue.isEmpty {
      let item = queue.removeFirst()
      switch item.kind {
      case .module:
        return moduleOrSpecialization(item.description)
      case .moduleDescriptor:
        //Swift.logger.debug("This is a module descriptor \(item.description)")
        queue.append(contentsOf: item.children)
      case .boundGenericEnum:
        for child in item.children {
          if child.kind == .typeList && genericSpecializationType == nil {
            genericSpecializationType = child.module
          }
        }
        queue.append(contentsOf: item.children)
      case .genericSpecialization:
        // TODO: Only use the generic specialization param if the module was "Swift" (or other non-intresting modules)
        for child in item.children {
          if child.kind == .genericSpecializationParam && genericSpecializationType == nil {
            genericSpecializationType = child.module
          }
        }
      default:
        queue.append(contentsOf: item.children)
      }
    }
    return nil
  }

  var typeName: String? {
    var queue = [SwiftSymbol]()
    var fallbackName: String? = nil
    queue.append(self)
    while !queue.isEmpty {
      let item = queue.removeFirst()
      switch item.kind {
      case .enum:
        if item.module == "Swift" {
          fallbackName = item.children.lazy.compactMap { $0.typeName }.first
        } else {
          queue.append(contentsOf: item.children)
        }
      case .identifier:
        switch item.contents {
        case .name(let name):
          return name
        default:
          break
        }
      case .function:
        if let subFunction = item.children.first(where: { $0.kind == .function }),
          let typeName = subFunction.typeName
        {
          return typeName
        } else {
          fallthrough
        }
      case .variable:
        let filteredChildren = item.children.filter({
          $0.kind != .identifier && $0.kind != .localDeclName
        })
        queue.append(contentsOf: filteredChildren)
      case .extension:
        // First child is the module the extension is in
        queue.append(contentsOf: item.children.dropFirst())
      case .labelList:
        break
      case .module:
        break
      case .privateDeclName:
        let filteredChildren = item.children.filter { symbol in
          guard symbol.kind == .identifier else { return true }

          switch symbol.contents {
          case .name(let name):
            return !name.starts(with: "_")
          default:
            break
          }
          return true
        }
        queue.append(contentsOf: filteredChildren)
      default:
        queue.append(contentsOf: item.children)
      }
    }
    return fallbackName
  }
}
