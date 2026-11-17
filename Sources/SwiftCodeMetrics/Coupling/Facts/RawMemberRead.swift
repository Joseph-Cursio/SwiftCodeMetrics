//
//  RawMemberRead.swift
//  SwiftCodeMetrics
//
//  `Base.member` that is not a call's callee: a possible static, singleton
//  or module-qualified global (Spec §8.2).
//

/// A member access on a named base.
struct RawMemberRead: Codable, Hashable {
    /// The base's dotted names; empty for `Self`.
    var base: [String]
    /// Whether the base is `Self`.
    var baseIsSelfType: Bool
    /// Lookup results for the base's first name.
    var rootLookup: [StoredLookupResult]
    /// The member name.
    var member: String
    /// Where the access starts.
    var offset: Int
}
