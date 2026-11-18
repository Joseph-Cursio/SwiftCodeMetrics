//
//  NameLookup.swift
//  SwiftCodeMetrics
//
//  The one place the library calls SwiftLexicalLookup (Spec §7.2, Q25). It
//  uses only the public `lookup(_:with:)` and stores each result without
//  syntax nodes, so the module pass can run over decoded file passes.
//

import SwiftLexicalLookup
import SwiftSyntax

/// Runs lexical lookup and stores the results.
enum NameLookup {
    /// The first component of a lexical path inside a function body.
    static let localMarker = "#local"

    /// The results of looking `token` up from `node`, innermost first. A
    /// token with no identifier (`self`, `Self`, `super`, `init`) is never
    /// looked up: `lookup(nil)` returns every visible name.
    static func lookup(_ token: TokenSyntax, from node: some SyntaxProtocol) -> [StoredLookupResult] {
        guard let identifier = token.identifier else {
            return []
        }
        let results = node.lookup(identifier).compactMap(store)
        // With no build configuration, lexical lookup reads only `#else`
        // clauses. Every clause is walked (Spec §2.6), so a name declared
        // earlier in an enclosing clause is a local too.
        return declaredInEnclosingClause(identifier.name, before: Syntax(node)) ? [.local] + results : results
    }

    /// Whether `name` is declared by a statement before `node` in a `#if`
    /// clause that encloses it inside a body. A clause at file scope holds
    /// globals, free functions and types, which are never locals.
    private static func declaredInEnclosingClause(_ name: String, before node: Syntax) -> Bool {
        var child = node
        while let parent = child.parent {
            if parent.is(MemberBlockSyntax.self) || parent.is(SourceFileSyntax.self) {
                return false
            }
            if let items = parent.as(CodeBlockItemListSyntax.self),
               let clause = items.parent?.as(IfConfigClauseSyntax.self) {
                guard SyntaxFacts.isLocal(Syntax(clause)) else {
                    return false
                }
                for item in items {
                    if item.position >= child.position {
                        break
                    }
                    if declaredNames(item.item).contains(name) {
                        return true
                    }
                }
            }
            child = parent
        }
        return false
    }

    /// The names a statement-level declaration introduces.
    private static func declaredNames(_ item: CodeBlockItemSyntax.Item) -> [String] {
        guard case .decl(let declaration) = item else {
            if case .stmt(let statement) = item, let guardStatement = statement.as(GuardStmtSyntax.self) {
                return guardStatement.conditions.flatMap { boundNames($0.condition) }
            }
            return []
        }
        if let variable = declaration.as(VariableDeclSyntax.self) {
            return variable.bindings.flatMap { MemberFacts.names(in: $0.pattern) }
        }
        if let function = declaration.as(FunctionDeclSyntax.self) {
            return [SyntaxFacts.name(function.name)]
        }
        if let named = declaration.asProtocol(NamedDeclSyntax.self) {
            return [SyntaxFacts.name(named.name)]
        }
        return []
    }

    /// The names a `guard` condition binds: `let x`, `let (a, b)` and
    /// `case let .some(x)` alike.
    private static func boundNames(_ condition: ConditionElementSyntax.Condition) -> [String] {
        let pattern: PatternSyntax
        switch condition {
        case .optionalBinding(let binding):
            pattern = binding.pattern

        case .matchingPattern(let matching):
            pattern = matching.pattern

        default:
            return []
        }
        return pattern.tokens(viewMode: .sourceAccurate).compactMap { token in
            token.parent?.is(IdentifierPatternSyntax.self) == true ? SyntaxFacts.name(token) : nil
        }
    }

    /// The lexical path of a type or extension declaration: enclosing type
    /// names, an extension's extended type as written, and a `#local`
    /// marker first when the declaration sits in a function body.
    static func lexicalPath(of node: Syntax) -> [String] {
        var components: [String] = []
        var current: Syntax? = node
        while let ancestor = current {
            if let extensionDecl = ancestor.as(ExtensionDeclSyntax.self) {
                let extended = TypeSpelling.spelled(extensionDecl.extendedType)?.components ?? []
                components.insert(contentsOf: extended, at: 0)
            } else if let named = ancestor.asProtocol(NamedDeclSyntax.self), ancestor.isProtocol(DeclGroupSyntax.self) {
                components.insert(SyntaxFacts.name(named.name), at: 0)
                if SyntaxFacts.isLocal(ancestor) {
                    return [localMarker] + components
                }
            }
            current = ancestor.parent
        }
        return components
    }

    /// One result without syntax nodes.
    private static func store(_ result: LookupResult) -> StoredLookupResult? {
        switch result {
        case let .fromScope(_, names):
            return names.isEmpty ? nil : .local

        case .lookForMembers(let scope):
            return .members(typePath: lexicalPath(of: scope))

        case .lookForGenericParameters(let extensionDecl):
            return .genericParameters(typePath: lexicalPath(of: Syntax(extensionDecl)))

        case .lookForImplicitClosureParameters:
            return .implicitClosureParameters
        }
    }
}
