//
//  TypeSizes.swift
//  SwiftCodeMetrics
//
//  Member counts and stored properties (Spec §9.1).
//

/// A type's sizes.
public struct TypeSizes: Sendable, Codable, Hashable {
    /// Members (Spec §2.3), `#if` variants merged; for a protocol, its
    /// requirements other than associated types.
    public var nom: Int
    /// Instance members, `init` and `deinit` included.
    public var instanceMembers: Int
    /// `static` and `class` members.
    public var staticMembers: Int
    /// Initialisers, overlapping the partition.
    public var initialisers: Int
    /// Computed properties, overlapping the partition.
    public var computedProperties: Int
    /// Subscripts, overlapping the partition.
    public var subscripts: Int
    /// The type's own stored instance properties.
    public var noa: Int
    /// One fact per own stored instance property.
    public var storedProperties: [StoredPropertyFact]
    /// The number of enum cases; nil for other kinds.
    public var caseCount: Int?
}
