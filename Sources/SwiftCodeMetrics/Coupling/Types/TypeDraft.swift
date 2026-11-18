//
//  TypeDraft.swift
//  SwiftCodeMetrics
//
//  One type's results before the module-wide values (ceFamily, Ca, conformers) are known.
//

/// A type during the type pass.
struct TypeDraft {
    /// The type.
    let key: TypeKey
    /// Its table entry.
    let entry: TypeEntry
    /// Its members.
    let groups: [MemberGroup]
    /// Its declaration-level references, resolved.
    let declarationReferences: [TypeReference]
    /// Its references by target.
    let edges: TypeEdges
    /// Declared conformances.
    let conformances: [ConformanceFact]
    /// Every merged extension.
    let extensions: [ExtensionFact]
    /// The module class it inherits from.
    let superclass: TypeKey?
    /// A class's unresolved first inherited name.
    let possibleSuperclass: String?

    /// The module protocols it declares conformance to.
    var conformanceTargets: Set<TypeKey> {
        Set(conformances.compactMap(\.target))
    }

    /// Enum case names across `#if` variants.
    var caseNames: Set<String> {
        Set(entry.declarations.flatMap(\.declaration.caseNames))
    }

    /// Whether some member other than a nested type is an instance member.
    var hasInstanceMembers: Bool {
        entry.declarations.contains(where: \.declaration.hasInstanceMembers)
            || entry.extensionFacts.contains(where: \.declaration.hasInstanceMembers)
    }
}
