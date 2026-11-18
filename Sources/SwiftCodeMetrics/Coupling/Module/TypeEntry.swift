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
    /// Member typealiases by name, every variant, merged extensions included.
    private(set) var aliasVariants: [String: [TypealiasFact]] = [:]
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

    /// Adds a member typealias variant.
    mutating func add(_ alias: TypealiasFact) {
        aliasVariants[alias.name, default: []].append(alias)
    }

    /// The member typealias `name` as `file` sees it: a private one only in
    /// its own file. Variants that name different targets make the name
    /// ambiguous (Spec §7.3) rather than letting one win.
    func alias(named name: String, from file: String) -> (alias: TypealiasFact, isConflicting: Bool)? {
        let visible = (aliasVariants[name] ?? []).filter { $0.isFileScoped == false || $0.file == file }
        guard let first = visible.first else {
            return nil
        }
        let isConflicting = visible.contains { other in
            other.target != first.target || other.closure != first.closure
                || other.compositionMembers != first.compositionMembers
        }
        return (first, isConflicting)
    }
}
