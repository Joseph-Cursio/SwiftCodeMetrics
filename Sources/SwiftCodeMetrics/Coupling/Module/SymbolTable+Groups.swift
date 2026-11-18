//
//  SymbolTable+Groups.swift
//  SwiftCodeMetrics
//
//  Keys for extension groups (Spec §2.2): the extended type as resolved,
//  with module qualifiers stripped and module typealiases expanded, so
//  `extension Swift.String`, `extension String` and `extension Text` where
//  `Text = String` form one group.
//

extension SymbolTable {
    /// The path an extension group, or a type nested in one, is keyed by:
    /// the platform or external type the written path resolves to. A group
    /// never takes a module type's key, so `extension Swift.Result` in a
    /// module that declares `Result` keeps its written path.
    func groupPath(for components: [String], from file: String) -> [String] {
        var canonical = components
        switch resolve(SpelledType(components: components, moduleSelector: nil), from: qualifierContext(file: file)) {
        case .external(let name), .platform(let name):
            canonical = name.split(separator: ".").map(String.init)

        case .module(let key):
            // A module type nested in a group: `extension Celsius.Unit` where Unit sits under Double.
            return key.path

        case .ambiguous, .genericParameter, .opaqueAlias, .unresolved:
            break
        }
        return visible(byPath[canonical] ?? [], from: file).isEmpty ? canonical : SpelledType.dotted(components)
    }

    /// Whether a path's root is a module type that has no nested type, or
    /// member typealias, by the rest of the path.
    func isMissingNestedType(_ components: [String], from file: String) -> Bool {
        guard components.count > 1, let root = components.first else {
            return false
        }
        let context = qualifierContext(file: file)
        guard resolve(SpelledType(components: [root], moduleSelector: nil), from: context).isModuleType else {
            return false
        }
        switch resolve(SpelledType(components: components, moduleSelector: nil), from: context) {
        case .external, .module, .platform:
            return false

        case .ambiguous, .genericParameter, .opaqueAlias, .unresolved:
            return true
        }
    }

    /// File scope, with every platform and imported module known as a qualifier.
    func qualifierContext(file: String) -> ResolutionContext {
        ResolutionContext(
            file: file,
            knownModules: importedModules.union(PlatformModules.harvested).union([module]),
            importsXCTest: false,
            importsFoundation: false,
            chain: [],
            genericParameters: [],
            localOwners: []
        )
    }
}
