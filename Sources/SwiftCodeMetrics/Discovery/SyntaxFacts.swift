//
//  SyntaxFacts.swift
//  SwiftCodeMetrics
//
//  Questions about syntax nodes that need no walker state. The `#if`
//  condition rendering matches SwiftStats, so keys agree (Spec Q1).
//

import SwiftSyntax

/// Stateless facts about declarations and statements.
enum SyntaxFacts {
    /// A name without backticks: `` `default` `` is `default`, as a reference spells it.
    static func name(_ token: TokenSyntax) -> String {
        token.identifier?.name ?? token.text
    }

    /// A name written as text, without backticks.
    static func bare(_ text: String) -> String {
        let inner = text.dropFirst().dropLast()
        return text.hasPrefix("`") && text.hasSuffix("`") && inner.isEmpty == false ? String(inner) : text
    }

    /// Every attribute in a list, those inside `#if` clauses included (Spec §2.6).
    static func attributes(_ list: AttributeListSyntax) -> [AttributeSyntax] {
        list.flatMap { element -> [AttributeSyntax] in
            switch element {
            case .attribute(let attribute):
                return [attribute]

            case .ifConfigDecl(let ifConfig):
                return ifConfig.clauses.flatMap { clause -> [AttributeSyntax] in
                    guard case .attributes(let nested)? = clause.elements else {
                        return []
                    }
                    return attributes(nested)
                }
            }
        }
    }

    /// Whether the modifiers make a declaration `private` or `fileprivate`.
    /// `private(set)` restricts only the setter, so it doesn't count.
    static func isFileScoped(_ modifiers: DeclModifierListSyntax) -> Bool {
        modifiers.contains { modifier in
            modifier.detail == nil
                && (modifier.name.tokenKind == .keyword(.private) || modifier.name.tokenKind == .keyword(.fileprivate))
        }
    }

    /// Whether the modifiers include `static` or `class`.
    static func isTypeLevel(_ modifiers: DeclModifierListSyntax) -> Bool {
        modifiers.contains { modifier in
            modifier.name.tokenKind == .keyword(.static) || modifier.name.tokenKind == .keyword(.class)
        }
    }

    /// Whether an accessor block has code, as opposed to a protocol
    /// requirement such as `{ get set }`.
    static func hasBody(_ block: AccessorBlockSyntax) -> Bool {
        switch block.accessors {
        case .getter:
            return true

        case .accessors(let accessors):
            return accessors.contains { $0.body != nil }
        }
    }

    /// The `var`/`let` declaration a binding belongs to.
    static func variable(of binding: PatternBindingSyntax) -> VariableDeclSyntax? {
        binding.parent?.parent?.as(VariableDeclSyntax.self)
    }

    /// Whether a variable is a stored property of a type (in a member list)
    /// or a global (at file scope), looking through `#if` clauses. Local
    /// variables in a body are neither.
    static func isMemberOrGlobal(_ variable: VariableDeclSyntax) -> Bool {
        placement(of: variable) != .local
    }

    /// Whether any attribute in a list, inside `#if` clauses too, has arguments.
    static func hasAttributeArguments(_ list: AttributeListSyntax) -> Bool {
        list.contains { element in
            switch element {
            case .attribute(let attribute):
                return attribute.arguments != nil

            case .ifConfigDecl(let block):
                return block.clauses.contains { clause in
                    clause.elements?.as(AttributeListSyntax.self).map(hasAttributeArguments) ?? false
                }
            }
        }
    }

    /// Whether a variable is declared at file scope.
    static func isGlobal(_ variable: VariableDeclSyntax) -> Bool {
        placement(of: variable) == .global
    }

    /// The condition under which a clause's body is compiled: its own
    /// condition, after the negation of every earlier clause's.
    static func condition(of clause: IfConfigClauseSyntax) -> String {
        var parts: [String] = []
        if let clauses = clause.parent?.as(IfConfigClauseListSyntax.self) {
            for sibling in clauses {
                if sibling.id == clause.id {
                    break
                }
                if let condition = sibling.condition {
                    parts.append("!(" + CanonicalText.render(condition) + ")")
                }
            }
        }
        if let condition = clause.condition {
            let own = CanonicalText.render(condition)
            // `!(A) && B || C` would read as `(!A && B) || C`.
            parts.append(parts.isEmpty || own.contains(" ") == false ? own : "(\(own))")
        }
        return parts.joined(separator: " && ")
    }

    /// Conditions joined with `&&`, each parenthesised when there are
    /// several and it contains a space.
    static func conjunction(_ conditions: [String]) -> String {
        guard conditions.count > 1 else {
            return conditions.first ?? ""
        }
        return conditions
            .map { $0.contains(" ") ? "(\($0))" : $0 }
            .joined(separator: " && ")
    }

    /// The file's top-level code: statements and expressions, and `#if`
    /// blocks that contain some, in source order. Declarations are not
    /// top-level code (Spec §2.1). A plain loop, not `filter`: filtering a
    /// syntax collection builds a detached copy whose positions are wrong.
    static func topLevelCode(_ items: CodeBlockItemListSyntax) -> [CodeBlockItemSyntax] {
        var code: [CodeBlockItemSyntax] = []
        for item in items where isTopLevelCode(item) {
            code.append(item)
        }
        return code
    }

    /// Where a variable declaration sits.
    private static func placement(of variable: VariableDeclSyntax) -> Placement {
        placement(ofDeclaration: Syntax(variable))
    }

    /// Whether a declaration sits in a body or closure rather than at file
    /// scope or in a member list, looking through `#if` clauses.
    static func isLocal(_ declaration: Syntax) -> Bool {
        placement(ofDeclaration: declaration) == .local
    }

    /// Where a declaration sits.
    private static func placement(ofDeclaration declaration: Syntax) -> Placement {
        var node = declaration.parent
        while let current = node {
            switch current.kind {
            case .codeBlockItem, .codeBlockItemList, .ifConfigClause, .ifConfigClauseList,
                .ifConfigDecl, .memberBlockItem, .memberBlockItemList:
                node = current.parent

            case .memberBlock:
                return .member

            case .sourceFile:
                return .global

            default:
                return .local
            }
        }
        return .local
    }

    /// Whether a top-level item is code rather than a declaration.
    private static func isTopLevelCode(_ item: CodeBlockItemSyntax) -> Bool {
        switch item.item {
        case .expr(let expression):
            // A top-level `#Preview { … }` parses as an expression but is a
            // declaration macro, not code that runs.
            return expression.is(MacroExpansionExprSyntax.self) == false

        case .stmt:
            return true

        case .decl(let declaration):
            guard let ifConfig = declaration.as(IfConfigDeclSyntax.self) else {
                return false
            }
            return ifConfig.clauses.contains { clause in
                guard case .statements(let nested)? = clause.elements else {
                    return false
                }
                return nested.contains(where: isTopLevelCode)
            }
        }
    }
}
