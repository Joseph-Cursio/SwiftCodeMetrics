//
//  CalleeShape.swift
//  SwiftCodeMetrics
//
//  What a call's callee looks like, before the module pass gives it a
//  receiver kind (Spec §7.5).
//

/// The syntactic form of a callee.
enum CalleeShape: Codable, Hashable {
    /// An unqualified name, with its lookup results.
    case bare(lookup: [StoredLookupResult])
    /// The base is a call result.
    case chain
    /// `.name(...)` with no base.
    case implicitMember
    /// Any other base expression.
    case other
    /// A dotted base of names, `A.B.name(...)`, with its root's lookup results.
    case qualified(base: [String], rootLookup: [StoredLookupResult])
    /// `self.name(...)` or `self?.name(...)`.
    case selfMember
    /// `Self.name(...)` or `Self(...)`.
    case selfType
    /// `super.name(...)`.
    case superMember
}
