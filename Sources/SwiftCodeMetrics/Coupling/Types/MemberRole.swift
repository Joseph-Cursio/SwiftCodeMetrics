//
//  MemberRole.swift
//  SwiftCodeMetrics
//
//  What kind of member a group of records forms (Spec §2.3).
//

/// The kind of a member.
enum MemberRole {
    /// A computed property, all accessors merged.
    case computedProperty
    /// A `deinit`.
    case deinitializer
    /// A `func`.
    case function
    /// An `init`.
    case initializer
    /// `willSet` and `didSet` of a stored property: not a member.
    case observer
    /// A subscript, all accessors merged.
    case subscriptMember
}
