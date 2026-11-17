//
//  RawName.swift
//  SwiftCodeMetrics
//
//  An unqualified value name that is not a callee (Spec §7.2).
//

/// A bare name and its lookup results.
struct RawName: Codable, Hashable {
    /// The name.
    var name: String
    /// Lookup results, innermost first.
    var lookup: [StoredLookupResult]
    /// Where it starts.
    var offset: Int
    /// Whether it is the base of a member access or a generic specialisation,
    /// where an uppercase name is a type-name candidate (Spec §7.3).
    var isTypePosition: Bool
}
