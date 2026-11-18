//
//  TypealiasFact.swift
//  SwiftCodeMetrics
//
//  A typealias, expanded one level at a time from its own position (Spec §7.3).
//

/// A declared typealias.
struct TypealiasFact: Codable, Hashable {
    /// Its name.
    var name: String
    /// Its target, when the target is a named type.
    var target: SpelledType?
    /// The members of a protocol composition target, `P & Q` (Spec §9.5).
    var compositionMembers: [SpelledType] = []
    /// Whether the target binds generic arguments (`Box<Int>`, `[Int]`), so
    /// an extension of the alias is constrained.
    var isBoundGeneric = false
    /// The target's closure shape: a function type (escaping if optional), a
    /// named type to expand further, or neither.
    var closure: ClosureShape
    /// The lexical type path it is declared in.
    var typePath: [String]
    /// The declaring file.
    var file: String
    /// Whether it is `private` or `fileprivate`.
    var isFileScoped: Bool
    /// Its own generic parameters: `typealias KeyOf<Model> = Model.Key`.
    var genericParameters: [String]
    /// The function that owns `typePath`, when the alias is in a local type.
    var localTo: MemberKey?
}
