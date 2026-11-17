//
//  ShadowedNames.swift
//  SwiftCodeMetrics
//
//  Names declared inside a function's own body: a bare call to one of them
//  is not a call to the function (Spec §3.4 rule 3).
//

import SwiftSyntax

/// Collects every name a function's own body declares.
final class ShadowedNames: OwnBodyVisitor {
    /// The names found.
    private(set) var names: Set<String> = []

    /// The names declared in `body`.
    static func names(in body: [Syntax]) -> Set<String> {
        let visitor = Self()
        for node in body {
            visitor.walk(node)
        }
        return visitor.names
    }

    override func visit(_ node: IdentifierPatternSyntax) -> SyntaxVisitorContinueKind {
        names.insert(node.identifier.text)
        return .visitChildren
    }

    override func visit(_ node: ClosureShorthandParameterSyntax) -> SyntaxVisitorContinueKind {
        names.insert(node.name.text)
        return .visitChildren
    }

    override func visit(_ node: ClosureParameterSyntax) -> SyntaxVisitorContinueKind {
        names.insert((node.secondName ?? node.firstName).text)
        return .visitChildren
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        names.insert(node.name.text)
        return .skipChildren
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        names.insert(node.name.text)
        return .skipChildren
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        names.insert(node.name.text)
        return .skipChildren
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        names.insert(node.name.text)
        return .skipChildren
    }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        names.insert(node.name.text)
        return .skipChildren
    }

    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        names.insert(node.name.text)
        return .skipChildren
    }

    deinit {
        // Nothing to release beyond stored properties.
    }
}
