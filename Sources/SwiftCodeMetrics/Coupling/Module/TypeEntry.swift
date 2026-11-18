//
//  TypeEntry.swift
//  SwiftCodeMetrics
//
//  One type of the module symbol table, merged with its extensions.
//

/// A module type and everything declared on it across files.
struct TypeEntry {
    /// The type's key.
    let key: TypeKey
    /// The kind.
    var kind: TypeKind
    /// Generic parameters and associated types.
    var genericParameters: Set<String>
    /// Inherited types of the primary declaration, in order.
    var inherited: [SpelledType]
    /// Members of the declaration and every merged extension.
    var members: [MemberFact]
    /// Nested types by simple name, merged extensions included.
    var nested: [String: [TypeKey]] = [:]
    /// Member typealiases by name, merged extensions included.
    var typealiases: [String: TypealiasFact] = [:]
    /// Member typealiases whose `#if` variants name different targets.
    var conflictingAliases: Set<String> = []
    /// A file that declares it, for resolving its inherited types.
    var file: String
    /// For a local type: the type path around its owning function.
    var enclosingTypePath: [String] = []
    /// For a local type: that path's own local owner, if it is local too.
    var enclosingLocalOwner: MemberKey?
    /// The primary declarations, one per `#if` variant; none for a group.
    var declarations: [TypeFact] = []
    /// The extensions merged into it.
    var extensionFacts: [ExtensionDeclFact] = []

    /// Adds a member typealias. `#if` variants that name different targets
    /// make the name ambiguous (Spec §7.3) rather than letting one win.
    mutating func add(_ alias: TypealiasFact) {
        if let existing = typealiases[alias.name],
           existing.target != alias.target || existing.closure != alias.closure
            || existing.compositionMembers != alias.compositionMembers {
            conflictingAliases.insert(alias.name)
        }
        typealiases[alias.name] = alias
    }
}
