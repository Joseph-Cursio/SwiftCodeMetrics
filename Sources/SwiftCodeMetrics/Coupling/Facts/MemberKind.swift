//
//  MemberKind.swift
//  SwiftCodeMetrics
//
//  The kinds of member the symbol table distinguishes.
//

/// What a member is.
enum MemberKind: String, Codable {
    /// A computed property.
    case computedProperty = "computed_property"
    /// An enum case.
    case enumCase = "enum_case"
    /// A method.
    case function
    /// An initialiser.
    case initializer
    /// A stored property.
    case storedProperty = "stored_property"
    /// A subscript.
    case subscriptMember = "subscript"

    /// Whether `staticRefs` counts it: a stored or computed property (Spec §8.2).
    var isProperty: Bool {
        self == .storedProperty || self == .computedProperty
    }
}
