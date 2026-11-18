//
//  TypeResult.swift
//  SwiftCodeMetrics
//
//  One type of a module, merged with its extensions (Spec §9, §13.5).
//

/// A type's sizes, complexity, cohesion and coupling.
public struct TypeResult: Sendable, Codable, Hashable {
    /// The type's key.
    public var key: TypeKey
    /// struct, class, enum, actor, protocol or extension group.
    public var kind: TypeKind
    /// Member counts and stored properties (Spec §9.1).
    public var sizes: TypeSizes
    /// Summed complexity of its functions (Spec §9.2).
    public var wmc: WMC
    /// LCOM4 and its groups (Spec §9.3).
    public var cohesion: CohesionResult
    /// Outgoing and incoming type coupling (Spec §9.4, §9.5).
    public var coupling: TypeCouplingSummary
    /// Type names outside function bodies: inheritance, generic and `where`
    /// clauses, stored properties, case payloads, typealiases, wrappers.
    public var declarationTypeReferences: [TypeReference]
    /// Unresolved type names, from declarations and member bodies (Spec §7.3).
    public var unresolvedTypeRefs: [String]
    /// Ambiguous type names.
    public var ambiguousTypeRefs: [String]
    /// Requirement and default counts, for protocols only.
    public var protocolFacts: ProtocolFacts?
    /// Every merged extension.
    public var extensions: [ExtensionFact]
    /// Declared conformances, from the declaration and every extension.
    public var conformances: [ConformanceFact]
    /// The superclass, when it is a module class.
    public var superclass: TypeKey?
    /// A class's first inherited name, when it resolves to nothing the module declares.
    public var possibleSuperclass: String?
    /// Custom attributes on the declaration.
    public var customAttributes: [String]
    /// Whether the type or a member carries a known attached macro.
    public var hasKnownAttachedMacro: Bool
}
