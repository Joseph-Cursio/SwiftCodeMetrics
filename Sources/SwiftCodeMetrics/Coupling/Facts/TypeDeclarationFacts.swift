//
//  TypeDeclarationFacts.swift
//  SwiftCodeMetrics
//
//  What a type or extension declaration adds beyond its members (Spec §9).
//

/// The facts of one type or extension declaration that type metrics need.
struct TypeDeclarationFacts: Codable, Hashable {
    /// The declaration's span.
    var range: ByteRange
    /// The extended type as written, for an extension; the name, for a type.
    var writtenName: String
    /// The canonical `where` clause, if any.
    var whereClause: String?
    /// For an extension: a `where` clause or bound generic arguments, which
    /// make its conformances conditional.
    var isConstrained: Bool
    /// Custom attributes on the declaration.
    var customAttributes: [String]
    /// Custom attributes on the declaration and its members.
    var attachedAttributeNames: [String]
    /// The inheritance clause.
    var inherited: [RawInherited]
    /// Enum case names, `#if` clauses included.
    var caseNames: [String]
    /// Stored instance properties.
    var storedProperties: [StoredPropertyFact]
    /// Whether any member other than a nested type is not `static` or `class`.
    var hasInstanceMembers: Bool
    /// Type names outside member bodies, each tagged with its edge kind.
    /// Inheritance-clause names carry `.inheritance` until the module pass
    /// knows the target's kind.
    var typeNames: [RawTypeName]
}
