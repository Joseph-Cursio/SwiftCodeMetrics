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
    /// A method's, initialiser's or subscript's argument labels, `_` for
    /// none; empty for other members.
    var labels: [String] = []
    /// A callable's or computed property's declaration as rendered in its key, so overloads with
    /// the same labels stay apart while `#if` variants merge.
    var declaration = ""

    /// The first property among same-named members, standing for every
    /// `#if` variant: a stored `var` (or singleton) in any configuration
    /// makes it one (Spec §2.6), whatever the clause order.
    static func firstProperty(_ members: [Self]) -> Self? {
        let properties = members.filter(\.kind.isProperty)
        guard var first = properties.first else {
            return nil
        }
        first.isStoredVar = properties.contains(where: \.isStoredVar)
        first.isSingletonCandidate = properties.contains(where: \.isSingletonCandidate)
        return first
    }
}
