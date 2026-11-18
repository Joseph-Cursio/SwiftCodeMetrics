//
//  RawKeyPath.swift
//  SwiftCodeMetrics
//
//  A key path's root and first component (Spec §9.3 rule 5).
//

/// A key path, as the cohesion graph reads it.
struct RawKeyPath: Codable, Hashable {
    /// The root type as written; empty for `\.name`.
    var root: [String]
    /// The first property component's name.
    var firstComponent: String
}
