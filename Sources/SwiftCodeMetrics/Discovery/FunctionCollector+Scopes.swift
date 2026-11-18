//
//  FunctionCollector+Scopes.swift
//  SwiftCodeMetrics
//
//  Scope bookkeeping and key assembly (PRD §6.1), as SwiftStats does it.
//

import SwiftSyntax

extension FunctionCollector {
    /// Whether the innermost scope is a record or context.
    var isInsideRecordScope: Bool {
        if case .record? = scopes.last {
            return true
        }
        return false
    }

    /// The nearest enclosing record, skipping contexts that are not records.
    var nearestRecord: Int? {
        for scope in scopes.reversed() {
            if case .record(let record) = scope, let index = record.draftIndex {
                return index
            }
        }
        return nil
    }

    /// Opens a type scope.
    func pushType(
        name: String,
        modifiers: DeclModifierListSyntax,
        owner: SyntaxIdentifier,
        genericParameters: [String]
    ) {
        scopes.append(.type(TypeScope(
            owner: owner,
            pathComponent: name,
            isFileScoped: SyntaxFacts.isFileScoped(modifiers),
            nominal: [SyntaxFacts.bare(name)],
            isExtension: false,
            genericParameters: genericParameters
        )))
    }

    /// Opens an extension's scope: the extended type plus its `where` clause.
    func pushExtension(_ node: ExtensionDeclSyntax) {
        let extended = CanonicalText.render(node.extendedType)
        let whereClause = node.genericWhereClause.map { " " + CanonicalText.render($0) } ?? ""
        let isFileScoped = SyntaxFacts.isFileScoped(node.modifiers)
            || FileScopedTypes.isFileScoped(extended, in: fileScopedTypes)
        scopes.append(.type(TypeScope(
            owner: node.id,
            pathComponent: extended + whereClause,
            isFileScoped: isFileScoped,
            nominal: TypeSpelling.spelled(node.extendedType)?.components ?? [extended],
            isExtension: true,
            genericParameters: []
        )))
    }

    /// Opens a key context that is not a record.
    func pushContext(declaration: String, isFileScoped: Bool, owner: SyntaxIdentifier) {
        let key = numbered(makeKey(declaration: declaration, isFileScoped: isFileScoped))
        scopes.append(.record(RecordScope(
            owner: owner,
            fullKey: key.full,
            conditionDepth: conditions.count,
            draftIndex: nil,
            genericParameters: []
        )))
    }

    /// Opens a key context for a freestanding macro that no record encloses.
    func openMacroContext(name: String, owner: SyntaxIdentifier) {
        let insideRecord = scopes.contains { scope in
            if case .record = scope {
                return true
            }
            return false
        }
        if insideRecord == false {
            pushContext(declaration: "#" + name, isFileScoped: true, owner: owner)
        }
    }

    /// Closes the innermost scope if `owner` opened it.
    func popScope(owner: SyntaxIdentifier) {
        if scopes.last?.owner == owner {
            scopes.removeLast()
        }
    }

    /// Opens the scopes of the types and `#if` clauses around `node`, for
    /// the declaration form, which starts below the file.
    func seedScopes(around node: Syntax) {
        var ancestors: [Syntax] = []
        var current = node.parent
        while let ancestor = current {
            ancestors.insert(ancestor, at: 0)
            current = ancestor.parent
        }
        if let file = ancestors.first?.as(SourceFileSyntax.self) {
            fileScopedTypes = FileScopedTypes.paths(in: file)
        }
        for ancestor in ancestors {
            seedScope(ancestor)
        }
    }

    /// Assembles a key from the open scopes. Inside a record or context its
    /// key is the prefix; otherwise the module and type path are.
    func makeKey(declaration: String, isFileScoped: Bool) -> AssembledKey {
        var prefix: RecordScope?
        var typeScopes: [TypeScope] = []
        for scope in scopes {
            switch scope {
            case .record(let record):
                prefix = record
                typeScopes = []

            case .type(let type):
                typeScopes.append(type)
            }
        }
        let modulePrefix = context.module + "::"
        var text = prefix.map { String($0.fullKey.dropFirst(modulePrefix.count)) + " / " } ?? ""
        let path = typeScopes.map(\.pathComponent).joined(separator: ".")
        if path.isEmpty == false {
            text += path + "::"
        }
        text += declaration
        let localConditions = Array(conditions.dropFirst(prefix?.conditionDepth ?? 0))
        if localConditions.isEmpty == false {
            text += " #if " + SyntaxFacts.conjunction(localConditions)
        }
        let needsFile = prefix == nil && (isFileScoped || typeScopes.contains(where: \.isFileScoped))
        return AssembledKey(text: text, file: needsFile ? context.file : nil, isNested: prefix != nil)
    }

    /// Numbers repeats of a nested key (`if … { func f() } else { func f() }`)
    /// and returns the key and its full string.
    func numbered(_ assembled: AssembledKey) -> (key: MemberKey, full: String) {
        var text = assembled.text
        if assembled.isNested {
            let occurrence = nestedKeyCounts[text, default: 0] + 1
            nestedKeyCounts[text] = occurrence
            if occurrence > 1 {
                text += " #\(occurrence)"
            }
        }
        let key = MemberKey(module: context.module, text: text, file: assembled.file)
        return (key, key.description)
    }

    /// Opens the scope one ancestor of a seeded declaration contributes.
    private func seedScope(_ ancestor: Syntax) {
        if let type = ancestor.asProtocol(NamedDeclSyntax.self), let group = ancestor.asProtocol(DeclGroupSyntax.self) {
            let genericClause = ancestor.asProtocol(WithGenericParametersSyntax.self)?.genericParameterClause
            let generics = TypeSpelling.names(of: genericClause)
            pushType(name: type.name.text, modifiers: group.modifiers, owner: ancestor.id, genericParameters: generics)
        } else if let extensionDecl = ancestor.as(ExtensionDeclSyntax.self) {
            pushExtension(extensionDecl)
        } else if let clause = ancestor.as(IfConfigClauseSyntax.self) {
            conditions.append(SyntaxFacts.condition(of: clause))
        }
    }
}
