//
//  RawInherited.swift
//  SwiftCodeMetrics
//
//  One entry of an inheritance clause, as written (Spec §9.1).
//

/// An inherited name: attributes unwrapped, `P & Q` split, `~Copyable` dropped.
struct RawInherited: Codable, Hashable {
    /// The name as written.
    var name: String
    /// The name as a type, when it is a plain or member type.
    var type: SpelledType?
}
