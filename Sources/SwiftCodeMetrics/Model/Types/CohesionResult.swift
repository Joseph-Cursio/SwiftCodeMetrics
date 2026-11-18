//
//  CohesionResult.swift
//  SwiftCodeMetrics
//
//  LCOM4 and what it is built from (Spec §9.3).
//

/// A type's cohesion.
public struct CohesionResult: Sendable, Codable, Hashable {
    /// The number of counted components; nil with a reason when not defined.
    public var lcom4: Int?
    /// Why `lcom4` is nil: the first reason that holds.
    public var nullReason: CohesionNullReason?
    /// The counted components.
    public var components: [CohesionComponent]
    /// Members in attribute-free components.
    public var isolatedMembers: [MemberKey]
    /// Members left out of the graph, each with a reason.
    public var excludedMembers: [ExcludedMember]
    /// Own attributes that no node touches.
    public var unusedAttributes: [String]
    /// Names that reach member lookup but are not declared in the type or
    /// its in-module superclasses.
    public var unresolvedMemberRefs: [String]
    /// Inherited members called or read, which add no edge.
    public var inheritedMemberRefs: [String]
    /// First components of rootless key paths that match an attribute.
    public var rootlessKeyPathNames: [String]
    /// The number of nodes, |M|.
    public var nodeCount: Int
    /// The type's own stored instance properties.
    public var noa: Int
    /// |A|, with in-module superclass attributes.
    public var attributeCount: Int
}
