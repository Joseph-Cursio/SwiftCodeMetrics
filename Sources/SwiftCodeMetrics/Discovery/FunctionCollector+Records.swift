//
//  FunctionCollector+Records.swift
//  SwiftCodeMetrics
//
//  Adding records: scoring the body, building the key, and opening the
//  record's scope for the declarations inside it.
//

import SwiftSyntax

extension FunctionCollector {
    /// Top-level statements, descending into `#if` clauses, as SwiftStats
    /// scopes them. A plain loop, not `filter`: filtering a syntax
    /// collection builds a detached copy whose positions are wrong.
    private static func collectStatements(
        _ items: CodeBlockItemListSyntax,
        into statements: inout [CodeBlockItemSyntax]
    ) {
        for item in items {
            switch item.item {
            case .expr(let expression):
                if expression.is(MacroExpansionExprSyntax.self) == false {
                    statements.append(item)
                }

            case .stmt:
                statements.append(item)

            case .decl(let declaration):
                guard let ifConfig = declaration.as(IfConfigDeclSyntax.self) else {
                    continue
                }
                for clause in ifConfig.clauses {
                    if case .statements(let nested)? = clause.elements {
                        collectStatements(nested, into: &statements)
                    }
                }
            }
        }
    }

    /// Scores `body`, collects its raw references, records it under the
    /// current scopes and opens its scope.
    func addRecord(_ head: RecordHead, body: ScoredBody, coupling: CouplingHead) {
        let raw = rawReferences(head: coupling, body: body.nodes)
        addRecord(head, scores: scorer.score(body), raw: raw, range: head.node)
    }

    /// A record with no recursion check and no builder hint.
    func addPlainRecord(_ head: RecordHead, body: Syntax, coupling: CouplingHead) {
        addRecord(
            head,
            body: ScoredBody(
                nodes: [body],
                kind: head.kind,
                recursion: nil,
                hint: nil,
                hasSyntaxErrors: head.node.hasError
            ),
            coupling: coupling
        )
    }

    /// A stored property's or global's initial value.
    func addInitialValue(_ node: InitializerClauseSyntax, binding: PatternBindingSyntax, variable: VariableDeclSyntax) {
        let declaration = DeclarationRenderer.initializerContext(binding, variable: variable)
        let isFileScoped = SyntaxFacts.isFileScoped(variable.modifiers)
        let scores = scorer.score(ScoredBody(
            nodes: [Syntax(node.value)],
            kind: .propertyInitializer,
            recursion: nil,
            hint: nil,
            hasSyntaxErrors: binding.hasError
        ))
        guard scores.cognitive > 0 || scores.decisionCount > 0 else {
            pushContext(declaration: declaration, isFileScoped: isFileScoped, owner: node.id)
            return
        }
        let head = RecordHead(
            kind: .propertyInitializer,
            name: CanonicalText.render(binding.pattern) + ".initializer",
            declaration: declaration,
            isFileScoped: isFileScoped,
            node: Syntax(binding)
        )
        addRecord(head, scores: scores, raw: nil, range: Syntax(binding), owner: node.id)
    }

    /// The file's `.topLevelCode` record, when it has top-level statements.
    func addTopLevelCode(_ file: SourceFileSyntax) {
        var statements: [CodeBlockItemSyntax] = []
        Self.collectStatements(file.statements, into: &statements)
        guard let first = statements.first, let last = statements.last else {
            return
        }
        let code = SyntaxFacts.topLevelCode(file.statements).map(Syntax.init)
        let scores = scorer.score(ScoredBody(
            nodes: code,
            kind: .topLevelCode,
            recursion: nil,
            hint: nil,
            // Any broken item inside the record's range counts (Spec §2.8),
            // declarations between the statements included.
            hasSyntaxErrors: file.statements.contains { item in
                item.hasError && item.endPosition > first.position && item.position < last.endPosition
            }
        ))
        let raw = rawReferences(head: .empty, body: statements.map(Syntax.init))
        let key = numbered(makeKey(declaration: "<top-level code>", isFileScoped: true))
        let start = first.positionAfterSkippingLeadingTrivia
        let end = last.endPositionBeforeTrailingTrivia
        drafts.append(FunctionDraft(
            parentDraft: nil,
            key: key.key,
            fullKey: key.full,
            kind: .topLevelCode,
            name: "<top-level code>",
            range: ByteRange(start: start.utf8Offset, end: end.utf8Offset),
            lines: lineRange(from: start, to: end),
            complexity: scores,
            raw: raw
        ))
        topLevelScope = RecordScope(
            owner: file.id,
            fullKey: key.full,
            conditionDepth: 0,
            draftIndex: drafts.count - 1,
            genericParameters: []
        )
        topLevelStatements = Set(statements.map(\.id))
    }

    /// The builder hint for a body with these attributes and result type.
    func hint(attributes: [AttributeListSyntax], resultType: TypeSyntax?) -> ResultBuilderHint? {
        ResultBuilderHints.hint(
            attributes: attributes,
            resultType: resultType,
            protocols: context.options.complexity.opaqueResultBuilderProtocols
        )
    }

    /// Records scored values and opens the record's scope, owned by the
    /// record's node unless `owner` says otherwise.
    private func addRecord(
        _ head: RecordHead,
        scores: ComplexityScores,
        raw: RawFunctionReferences?,
        range node: Syntax,
        owner: SyntaxIdentifier? = nil
    ) {
        let parent = nearestRecord
        let key = numbered(makeKey(declaration: head.declaration, isFileScoped: head.isFileScoped))
        let start = node.positionAfterSkippingLeadingTrivia
        let end = node.endPositionBeforeTrailingTrivia
        drafts.append(FunctionDraft(
            parentDraft: parent,
            key: key.key,
            fullKey: key.full,
            kind: head.kind,
            name: head.name,
            range: ByteRange(start: start.utf8Offset, end: end.utf8Offset),
            lines: lineRange(from: start, to: end),
            complexity: scores,
            raw: raw
        ))
        scopes.append(.record(RecordScope(
            owner: owner ?? node.id,
            fullKey: key.full,
            conditionDepth: conditions.count,
            draftIndex: drafts.count - 1,
            genericParameters: raw?.context.genericParameters ?? []
        )))
    }

    /// The span in lines; the end is the last character.
    private func lineRange(from start: AbsolutePosition, to end: AbsolutePosition) -> LineRange? {
        guard let converter = context.converter else {
            return nil
        }
        let first = converter.location(for: start)
        let lastCharacter = AbsolutePosition(utf8Offset: max(start.utf8Offset, end.utf8Offset - 1))
        let last = converter.location(for: lastCharacter)
        return LineRange(startLine: first.line, startColumn: first.column, endLine: last.line, endColumn: last.column)
    }
}
