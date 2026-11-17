//
//  MemberFact.swift
//  SwiftCodeMetrics
//
//  One member of a type or extension, for the symbol table.
//

/// A declared member.
struct MemberFact: Codable, Hashable {
    /// Its base name.
    var name: String
    /// `static` or `class`.
    var isTypeLevel: Bool
    /// What it is.
    var kind: MemberKind
    /// A stored `var` (for `mutableStaticRefs`).
    var isStoredVar: Bool
    /// A stored static initialised by its own type: `T(...)`, `Self(...)` or `.init(...)`.
    var isSingletonCandidate: Bool
    /// A method's argument labels, `_` for none; empty for other members.
    var labels: [String] = []
}
