//
//  SwiftLintVisitor.swift
//  SwiftCodeMetrics
//
//  SwiftLint's `cyclomatic_complexity`, reproduced exactly (Spec §4.3): it
//  skips only nested `func` and `init`, so local types, accessors and
//  closures fold in, and every `#if` clause is summed.
//

import SwiftSyntax

/// Scores a body the way SwiftLint 0.65.1 does.
final class SwiftLintVisitor: SyntaxVisitor {
    /// The breakdown so far.
    private(set) var items: [Increment] = []

    /// Builds items.
    private let factory: IncrementFactory
    /// SwiftLint's `ignores_case_statements`.
    private let ignoresCaseStatements: Bool

    /// Creates a visitor.
    init(factory: IncrementFactory, ignoresCaseStatements: Bool) {
        self.factory = factory
        self.ignoresCaseStatements = ignoresCaseStatements
        super.init(viewMode: .sourceAccurate)
    }

    /// A type or extension at file scope, inside a top-level `#if` that also
    /// holds statements, is not top-level code (Spec §2.1); a local type in a
    /// function body folds in, as SwiftLint folds it.
    private static func skipAtFileScope(_ node: some DeclSyntaxProtocol) -> SyntaxVisitorContinueKind {
        SyntaxFacts.isLocal(Syntax(node)) ? .visitChildren : .skipChildren
    }

    override func visit(_: UnexpectedNodesSyntax) -> SyntaxVisitorContinueKind {
        .skipChildren
    }

    override func visit(_: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        .skipChildren
    }

    override func visit(_: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        .skipChildren
    }

    /// A global's initial value is not top-level code (Spec §2.1).
    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        SyntaxFacts.isGlobal(node) ? .skipChildren : .visitChildren
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        Self.skipAtFileScope(node)
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        Self.skipAtFileScope(node)
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        Self.skipAtFileScope(node)
    }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        Self.skipAtFileScope(node)
    }

    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        Self.skipAtFileScope(node)
    }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        Self.skipAtFileScope(node)
    }

    override func visitPost(_ node: ForStmtSyntax) {
        add(.loop, amount: 1, anchor: node.forKeyword)
    }

    override func visitPost(_ node: IfExprSyntax) {
        let isElseIf = node.parent?.as(IfExprSyntax.self)?.elseBody?.as(IfExprSyntax.self)?.id == node.id
        add(isElseIf ? .elseIf : .ifStatement, amount: 1, anchor: node.ifKeyword)
    }

    override func visitPost(_ node: GuardStmtSyntax) {
        add(.guardStatement, amount: 1, anchor: node.guardKeyword)
    }

    override func visitPost(_ node: RepeatStmtSyntax) {
        add(.loop, amount: 1, anchor: node.repeatKeyword)
    }

    override func visitPost(_ node: WhileStmtSyntax) {
        add(.loop, amount: 1, anchor: node.whileKeyword)
    }

    override func visitPost(_ node: CatchClauseSyntax) {
        add(.catchClause, amount: 1, anchor: node.catchKeyword)
    }

    override func visitPost(_ node: SwitchCaseSyntax) {
        guard ignoresCaseStatements == false else {
            return
        }
        switch node.label {
        case .case(let label):
            add(.switchCase, amount: 1, anchor: label.caseKeyword)

        case .default(let label):
            add(.switchCase, amount: 1, anchor: label.defaultKeyword)
        }
    }

    override func visitPost(_ node: FallThroughStmtSyntax) {
        if ignoresCaseStatements == false {
            add(.fallthroughStatement, amount: -1, anchor: node.fallthroughKeyword)
        }
    }

    /// Adds one item.
    private func add(_ rule: Increment.Rule, amount: Int, anchor: TokenSyntax) {
        items.append(factory.make(.swiftLint, rule, amount: amount, anchor: anchor))
    }

    deinit {
        // Nothing to release beyond stored properties.
    }
}
