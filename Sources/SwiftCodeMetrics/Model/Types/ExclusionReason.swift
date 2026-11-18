//
//  ExclusionReason.swift
//  SwiftCodeMetrics
//
//  Why a member is not a cohesion node (Spec §9.3).
//

/// The reasons a member is left out of M.
public enum ExclusionReason: String, Sendable, Codable, Hashable {
    /// A `deinit`.
    case deinitializer
    /// `description`, `debugDescription` or `customMirror`.
    case descriptionWitness = "description_witness"
    /// An `init`.
    case initializer
    /// A `willSet` or `didSet`, which belongs to its stored property.
    case observer
    /// A `static` or `class` member.
    case typeLevel = "type_level"
    /// `hash(into:)`, `hashValue` or `encode(to:)`.
    case wholeValueWitness = "whole_value_witness"
}
