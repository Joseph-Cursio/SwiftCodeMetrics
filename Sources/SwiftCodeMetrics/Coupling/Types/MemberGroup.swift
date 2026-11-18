//
//  MemberGroup.swift
//  SwiftCodeMetrics
//
//  One member of a type: its records across accessors, nested functions and #if variants (Spec §2.3, §2.6).
//

/// A member and the records it is made of.
struct MemberGroup {
    /// The member's key: its declaration, without `#if` conditions or accessor.
    let key: MemberKey
    /// What it is.
    let role: MemberRole
    /// Whether it is `static` or `class`.
    var isTypeLevel: Bool
    /// Whether it is a member (Spec §2.3); false for a function inside a
    /// stored property's initial value, which is only a WMC term.
    let isMember: Bool
    /// The base name, backticks stripped: `load`, `total`, `subscript`, `init`.
    let baseName: String
    /// The argument labels; empty for properties.
    let labels: [String]
    /// The member's own records (accessors included), by `#if` condition.
    var variants: [String: [Int]]
    /// Every record that belongs to it: its own and their nested functions.
    var records: [Int]

    /// The first of its own records.
    var firstRecord: Int {
        variants.values.flatMap(\.self).min() ?? records.min() ?? 0
    }
}
