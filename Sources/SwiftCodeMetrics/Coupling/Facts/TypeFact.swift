//
//  TypeFact.swift
//  SwiftCodeMetrics
//
//  One type declaration, for the module symbol table.
//

/// A declared type and its own members.
struct TypeFact: Codable, Hashable {
    /// Its lexical path; an enclosing extension contributes its extended type as written.
    var path: [String]
    /// How many leading `path` components came from an extension.
    var extensionPathLength: Int
    /// The owning function, for a local type.
    var localTo: MemberKey?
    /// For a local type: the type path around its owning function.
    var enclosingTypePath: [String]
    /// For a local type: that path's own local owner, if it is local too.
    var enclosingLocalOwner: MemberKey?
    /// The kind.
    var kind: TypeKind
    /// Whether it is `private` or `fileprivate`, directly or by nesting.
    var isFileScoped: Bool
    /// The declaring file.
    var file: String
    /// Its generic parameters, or a protocol's primary associated types.
    var genericParameters: [String]
    /// A protocol's associated types.
    var associatedTypes: [String]
    /// The inherited types, in order.
    var inherited: [SpelledType]
    /// How many of `inherited` the first written entry names: two for
    /// `class Card: Themed & Base`, any of which can be the superclass.
    var firstEntryCount = 1
    /// Members declared in the primary declaration.
    var members: [MemberFact]
    /// Member typealiases.
    var typealiases: [TypealiasFact]
    /// Declaration-level facts for type metrics.
    var declaration: TypeDeclarationFacts
    /// For a local type: every enclosing record, nearest last, so a type in
    /// a nested function sees the outer function's local types too.
    var enclosingRecords: [MemberKey] = []

    /// The records whose local types its declaration sees, nearest last.
    var visibleRecords: [MemberKey] {
        enclosingRecords.isEmpty ? (localTo.map { [$0] } ?? []) : enclosingRecords
    }
}
