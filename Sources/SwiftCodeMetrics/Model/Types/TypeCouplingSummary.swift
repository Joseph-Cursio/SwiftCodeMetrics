//
//  TypeCouplingSummary.swift
//  SwiftCodeMetrics
//
//  A type's outgoing and incoming coupling counts (Spec §9.4, §9.5).
//

/// Type-level coupling.
public struct TypeCouplingSummary: Sendable, Codable, Hashable {
    /// `ce`: distinct module types named outside the nesting family.
    public var ceTotal: Int
    /// Targets that are concrete types.
    public var ceConcrete: Int
    /// Targets that are protocols.
    public var ceProtocol: Int
    /// Targets that are SwiftUI views.
    public var ceView: Int
    /// Targets that are namespace enums.
    public var ceNamespace: Int
    /// Targets of the type and its nested types, collapsed to outermost types.
    public var ceFamily: Int
    /// Distinct types of the own nesting family that are named.
    public var internalRefs: Int
    /// Distinct `external` names, a lower bound.
    public var externalNameCount: Int
    /// Distinct `platform` names.
    public var platformNameCount: Int
    /// Distinct module types with an edge to this type.
    public var caWithinModule: Int
    /// The number of distinct unresolved type names.
    public var unresolvedTypeRefCount: Int
    /// The number of distinct ambiguous type names.
    public var ambiguousTypeRefCount: Int
}
