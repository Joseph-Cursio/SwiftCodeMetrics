//
//  TypeReference.swift
//  SwiftCodeMetrics
//
//  One type name a function uses, and what it resolved to (Spec §13.2).
//

/// A type name in a function's signature or body.
public struct TypeReference: Sendable, Codable, Hashable {
    /// As written, generic arguments stripped: `Shop.Item`.
    public var spelling: String
    /// `signature` or `body`.
    public var edgeKind: EdgeKind
    /// Where the name starts.
    public var utf8Offset: Int
    /// Module, platform or external; nil until the module pass, and for
    /// unresolved or ambiguous names.
    public var bucket: TypeBucket?
    /// The module type, for the `module` bucket.
    public var target: TypeKey?
    /// How sure the target is.
    public var resolution: Resolution
}
