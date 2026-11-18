//
//  FunctionCollector.swift
//  SwiftCodeMetrics
//
//  Walks a file or declaration and scores every function record of Spec
//  §2.1. Scopes and `#if` conditions build each record's key the way
//  SwiftStats does, so the two tools agree on identity (Spec Q1).
//

import SwiftSyntax

/// Collects and scores the function records under one node.
final class FunctionCollector: SyntaxVisitor {
    /// The records found so far, in visit order.
    var drafts: [FunctionDraft] = []
    /// Open type and record scopes, outermost first.
    var scopes: [CollectorScope] = []
    /// Open `#if` conditions, outermost first.
    var conditions: [String] = []
    /// How often each nested key has been seen, to number repeats.
    var nestedKeyCounts: [String: Int] = [:]
    /// Types this file declares `private` or `fileprivate`.
    var fileScopedTypes: Set<String> = []
    /// The file's declarations.
    var declarations = DeclarationFacts()
    /// The file's imports.
    var imports: [ImportFact] = []
    /// The file's top-level-code record, if it has one.
    var topLevelScope: RecordScope?
    /// The top-level statements that record covers.
    var topLevelStatements: Set<SyntaxIdentifier> = []

    /// The settings.
    let context: CollectorContext
    /// Scores each body.
    let scorer: ComplexityScorer

    /// Creates a collector.
    init(context: CollectorContext) {
        self.context = context
        self.scorer = ComplexityScorer(
            options: context.options.complexity,
            factory: IncrementFactory(converter: context.converter)
        )
        super.init(viewMode: .sourceAccurate)
    }

    // MARK: - Files and types

    override func visit(_ node: SourceFileSyntax) -> SyntaxVisitorContinueKind {
        fileScopedTypes = FileScopedTypes.paths(in: node)
        if context.includesTopLevelCode {
            addTopLevelCode(node)
        }
        return .visitChildren
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        openType(node, kind: .`struct`)
        return .visitChildren
    }

    override func visitPost(_ node: StructDeclSyntax) {
        popScope(owner: node.id)
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        openType(node, kind: .`class`)
        return .visitChildren
    }

    override func visitPost(_ node: ClassDeclSyntax) {
        popScope(owner: node.id)
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        openType(node, kind: .`enum`)
        return .visitChildren
    }

    override func visitPost(_ node: EnumDeclSyntax) {
        popScope(owner: node.id)
    }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        openType(node, kind: .actor)
        return .visitChildren
    }

    override func visitPost(_ node: ActorDeclSyntax) {
        popScope(owner: node.id)
    }

    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        openType(node, kind: .`protocol`)
        return .visitChildren
    }

    override func visitPost(_ node: ProtocolDeclSyntax) {
        popScope(owner: node.id)
    }

    override func visit(_ node: MacroDeclSyntax) -> SyntaxVisitorContinueKind {
        declarations.macroNames.append(SyntaxFacts.name(node.name))
        return .skipChildren
    }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        openExtension(node)
        return .visitChildren
    }

    override func visitPost(_ node: ExtensionDeclSyntax) {
        popScope(owner: node.id)
    }

    // MARK: - Contexts

    /// A top-level statement: declarations inside it belong to the file's
    /// top-level-code record.
    override func visit(_ node: CodeBlockItemSyntax) -> SyntaxVisitorContinueKind {
        if let topLevelScope, topLevelStatements.contains(node.id) {
            scopes.append(.record(RecordScope(
                owner: node.id,
                fullKey: topLevelScope.fullKey,
                conditionDepth: 0,
                draftIndex: topLevelScope.draftIndex,
                genericParameters: []
            )))
        }
        return .visitChildren
    }

    override func visitPost(_ node: CodeBlockItemSyntax) {
        popScope(owner: node.id)
    }

    /// A stored property's or global's initial value: a record when its C
    /// or D is non-zero, otherwise a key context (Spec §2.1).
    override func visit(_ node: InitializerClauseSyntax) -> SyntaxVisitorContinueKind {
        if let binding = node.parent?.as(PatternBindingSyntax.self),
           let variable = SyntaxFacts.variable(of: binding),
           SyntaxFacts.isMemberOrGlobal(variable),
           isInsideRecordScope == false {
            addInitialValue(node, binding: binding, variable: variable)
        }
        return .visitChildren
    }

    override func visitPost(_ node: InitializerClauseSyntax) {
        popScope(owner: node.id)
    }

    /// A member variable's attribute arguments (`@Clamped({ ... })`) are a
    /// key context, like an initial value: functions in them are not members.
    override func visit(_ node: AttributeListSyntax) -> SyntaxVisitorContinueKind {
        if let variable = node.parent?.as(VariableDeclSyntax.self), SyntaxFacts.isMemberOrGlobal(variable),
           isInsideRecordScope == false, node.contains(where: { $0.as(AttributeSyntax.self)?.arguments != nil }) {
            pushContext(
                declaration: DeclarationRenderer.attributeContext(variable),
                isFileScoped: SyntaxFacts.isFileScoped(variable.modifiers),
                owner: node.id
            )
        }
        return .visitChildren
    }

    override func visitPost(_ node: AttributeListSyntax) {
        popScope(owner: node.id)
    }

    // MARK: - Records

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        collect(node)
    }

    override func visitPost(_ node: FunctionDeclSyntax) {
        popScope(owner: node.id)
    }

    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        collect(node)
    }

    override func visitPost(_ node: InitializerDeclSyntax) {
        popScope(owner: node.id)
    }

    override func visit(_ node: DeinitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        collect(node)
    }

    override func visitPost(_ node: DeinitializerDeclSyntax) {
        popScope(owner: node.id)
    }

    override func visit(_ node: SubscriptDeclSyntax) -> SyntaxVisitorContinueKind {
        collect(node)
    }

    override func visitPost(_ node: SubscriptDeclSyntax) {
        popScope(owner: node.id)
    }

    override func visit(_ node: AccessorBlockSyntax) -> SyntaxVisitorContinueKind {
        collect(node)
    }

    override func visitPost(_ node: AccessorBlockSyntax) {
        popScope(owner: node.id)
    }

    override func visit(_ node: AccessorDeclSyntax) -> SyntaxVisitorContinueKind {
        collect(node)
    }

    override func visitPost(_ node: AccessorDeclSyntax) {
        popScope(owner: node.id)
    }

    // MARK: - Macros

    /// A freestanding macro outside any record, such as `#Preview { ... }`,
    /// is a key context: types declared in its closures are local to it.
    override func visit(_ node: MacroExpansionExprSyntax) -> SyntaxVisitorContinueKind {
        openMacroContext(name: node.macroName.text, owner: node.id)
        return .visitChildren
    }

    override func visitPost(_ node: MacroExpansionExprSyntax) {
        popScope(owner: node.id)
    }

    override func visit(_ node: MacroExpansionDeclSyntax) -> SyntaxVisitorContinueKind {
        openMacroContext(name: node.macroName.text, owner: node.id)
        return .visitChildren
    }

    override func visitPost(_ node: MacroExpansionDeclSyntax) {
        popScope(owner: node.id)
    }

    // MARK: - Declarations

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        if SyntaxFacts.isGlobal(node) {
            recordGlobal(node)
        }
        return .visitChildren
    }

    override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
        if scopes.isEmpty {
            recordTypealias(node)
        }
        return .skipChildren
    }

    override func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
        recordImport(node)
        return .skipChildren
    }

    // MARK: - #if

    override func visit(_ node: IfConfigClauseSyntax) -> SyntaxVisitorContinueKind {
        conditions.append(SyntaxFacts.condition(of: node))
        return .visitChildren
    }

    override func visitPost(_: IfConfigClauseSyntax) {
        conditions.removeLast()
    }

    deinit {
        // Nothing to release beyond stored properties.
    }
}
