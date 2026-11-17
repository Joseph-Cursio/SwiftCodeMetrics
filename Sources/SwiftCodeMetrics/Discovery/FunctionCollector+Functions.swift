//
//  FunctionCollector+Functions.swift
//  SwiftCodeMetrics
//
//  The declarations that are records: functions, initialisers,
//  deinitialisers, subscripts and accessors. The overrides that call these
//  live in the class body, since overrides can't be declared in extensions.
//

import SwiftSyntax

extension FunctionCollector {
    func collect(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let body = node.body else {
            return .skipChildren
        }
        let nodes = [Syntax(body)]
        addRecord(
            RecordHead(
                kind: .function,
                name: FunctionNames.function(node),
                declaration: DeclarationRenderer.function(node),
                isFileScoped: SyntaxFacts.isFileScoped(node.modifiers),
                node: Syntax(node)
            ),
            body: ScoredBody(
                nodes: nodes,
                kind: .function,
                recursion: RecursionMatcher(function: node, body: nodes),
                hint: hint(attributes: [node.attributes], resultType: node.signature.returnClause?.type),
                hasSyntaxErrors: node.hasError
            ),
            coupling: CouplingHead(
                genericParameters: TypeSpelling.names(of: node.genericParameterClause),
                isTypeLevel: SyntaxFacts.isTypeLevel(node.modifiers),
                signature: CouplingHead.signature(of: node.signature.parameterClause.parameters)
                    + CouplingHead.signature(
                        generics: node.genericParameterClause,
                        result: node.signature.returnClause?.type,
                        whereClause: node.genericWhereClause
                    ) + CouplingHead.thrownType(node.signature.effectSpecifiers?.throwsClause),
                parameters: node.signature.parameterClause.parameters
            )
        )
        if scopes.count == 1 {
            declarations.freeFunctions.append(FreeFunctionFact(
                name: SyntaxFacts.name(node.name),
                file: context.file ?? "",
                isFileScoped: SyntaxFacts.isFileScoped(node.modifiers)
            ))
        }
        return .visitChildren
    }

    func collect(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let body = node.body else {
            return .skipChildren
        }
        addPlainRecord(
            RecordHead(
                kind: .initializer,
                name: FunctionNames.initializer(node),
                declaration: DeclarationRenderer.initializer(node),
                isFileScoped: SyntaxFacts.isFileScoped(node.modifiers),
                node: Syntax(node)
            ),
            body: Syntax(body),
            coupling: CouplingHead(
                genericParameters: TypeSpelling.names(of: node.genericParameterClause),
                isTypeLevel: false,
                signature: CouplingHead.signature(of: node.signature.parameterClause.parameters)
                    + CouplingHead.signature(
                        generics: node.genericParameterClause,
                        result: nil,
                        whereClause: node.genericWhereClause
                    ) + CouplingHead.thrownType(node.signature.effectSpecifiers?.throwsClause),
                parameters: node.signature.parameterClause.parameters
            )
        )
        return .visitChildren
    }

    func collect(_ node: DeinitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let body = node.body else {
            return .skipChildren
        }
        addPlainRecord(
            RecordHead(
                kind: .deinitializer,
                name: "deinit",
                declaration: "deinit",
                isFileScoped: false,
                node: Syntax(node)
            ),
            body: Syntax(body),
            coupling: .empty
        )
        return .visitChildren
    }

    /// A subscript with an implicit getter is one record. With explicit
    /// accessors, the accessors are the records and the subscript is only
    /// their key context (Spec §2.1, Q1).
    func collect(_ node: SubscriptDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let block = node.accessorBlock, SyntaxFacts.hasBody(block) else {
            return .skipChildren
        }
        let declaration = DeclarationRenderer.subscriptDeclaration(node)
        guard case .getter(let items) = block.accessors else {
            let isFileScoped = SyntaxFacts.isFileScoped(node.modifiers)
            pushContext(declaration: declaration, isFileScoped: isFileScoped, owner: node.id)
            return .visitChildren
        }
        addRecord(
            RecordHead(
                kind: .subscriptGetter,
                name: FunctionNames.subscriptDeclaration(node) + ".get",
                declaration: declaration,
                isFileScoped: SyntaxFacts.isFileScoped(node.modifiers),
                node: Syntax(node)
            ),
            body: ScoredBody(
                nodes: [Syntax(items)],
                kind: .subscriptGetter,
                recursion: nil,
                hint: hint(attributes: [node.attributes], resultType: node.returnClause.type),
                hasSyntaxErrors: node.hasError
            ),
            coupling: AccessorOwner.coupling(of: node, carriesParameters: true)
        )
        return .visitChildren
    }

    /// The implicit getter of a computed property: `var x: Int { … }`.
    func collect(_ node: AccessorBlockSyntax) -> SyntaxVisitorContinueKind {
        guard case .getter(let items) = node.accessors,
              let binding = node.parent?.as(PatternBindingSyntax.self) else {
            return .visitChildren
        }
        let variable = SyntaxFacts.variable(of: binding)
        addRecord(
            RecordHead(
                kind: .computedGetter,
                name: CanonicalText.render(binding.pattern) + ".get",
                declaration: DeclarationRenderer.accessor(
                    owner: DeclarationRenderer.property(binding, modifiers: variable?.modifiers),
                    kind: "get"
                ),
                isFileScoped: variable.map { SyntaxFacts.isFileScoped($0.modifiers) } ?? false,
                node: Syntax(node)
            ),
            body: ScoredBody(
                nodes: [Syntax(items)],
                kind: .computedGetter,
                recursion: nil,
                hint: hint(
                    attributes: variable.map { [$0.attributes] } ?? [],
                    resultType: binding.typeAnnotation?.type
                ),
                hasSyntaxErrors: node.hasError
            ),
            coupling: CouplingHead(
                genericParameters: [],
                isTypeLevel: variable.map { SyntaxFacts.isTypeLevel($0.modifiers) } ?? false,
                signature: binding.typeAnnotation.map { [Syntax($0.type)] } ?? [],
                parameters: nil
            )
        )
        return .visitChildren
    }

    /// An explicit accessor: `get`, `set`, `willSet`, `didSet`, `_modify`, …
    func collect(_ node: AccessorDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let body = node.body else {
            return .skipChildren
        }
        let owner = AccessorOwner(node)
        addRecord(
            RecordHead(
                kind: .accessor,
                name: owner.name + "." + node.accessorSpecifier.text,
                declaration: DeclarationRenderer.accessor(
                    owner: owner.declaration,
                    kind: node.accessorSpecifier.text
                ),
                isFileScoped: owner.isFileScoped,
                node: Syntax(node)
            ),
            body: ScoredBody(
                nodes: [Syntax(body)],
                kind: .accessor,
                recursion: nil,
                hint: hint(attributes: [node.attributes] + owner.attributes, resultType: owner.resultType),
                hasSyntaxErrors: node.hasError
            ),
            coupling: owner.coupling(for: node)
        )
        return .visitChildren
    }
}
