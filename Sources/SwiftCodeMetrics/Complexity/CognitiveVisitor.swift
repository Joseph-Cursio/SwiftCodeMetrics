//
//  CognitiveVisitor.swift
//  SwiftCodeMetrics
//
//  Swift cognitive complexity (Spec §3). Structural constructs cost 1 plus
//  the nesting level; hybrid and fundamental ones cost 1. Each handler walks
//  its own children so it can say which level they sit at.
//

import SwiftSyntax

/// Scores one function's own body for cognitive complexity.
final class CognitiveVisitor: OwnBodyVisitor {
    /// The breakdown so far.
    var items: [Increment] = []
    /// The deepest level given to any contents.
    var maxNesting = 0

    /// Builds items.
    let factory: IncrementFactory
    /// The recursion check; nil when off or not an ordinary `func`.
    private let recursion: RecursionMatcher?
    /// The current nesting level.
    var level = 0
    /// How much of `level` comes from enclosing closures.
    var closureLevel = 0
    /// Whether the once-per-function recursion item was added.
    private var hasRecursion = false

    /// Creates a visitor.
    init(factory: IncrementFactory, recursion: RecursionMatcher?) {
        self.factory = factory
        self.recursion = recursion
        super.init()
    }

    // MARK: - Branches

    override func visit(_ node: IfExprSyntax) -> SyntaxVisitorContinueKind {
        scoreIf(node, isElseIf: false)
        return .skipChildren
    }

    override func visit(_ node: GuardStmtSyntax) -> SyntaxVisitorContinueKind {
        fundamental(.guardStatement, anchor: node.guardKeyword)
        scoreConditions(node.conditions)
        nested(level + 1) { walk(node.body) }
        return .skipChildren
    }

    override func visit(_ node: SwitchExprSyntax) -> SyntaxVisitorContinueKind {
        structural(.switchStatement, anchor: node.switchKeyword)
        walk(node.subject)
        walkCases(node.cases, bodyLevel: level + 1)
        return .skipChildren
    }

    override func visit(_ node: IfConfigDeclSyntax) -> SyntaxVisitorContinueKind {
        // A `#if` in an attribute list selects attributes, not code.
        if node.parent?.is(AttributeListSyntax.self) == false {
            scoreIfConfig(node)
        }
        return .skipChildren
    }

    override func visit(_ node: CatchClauseSyntax) -> SyntaxVisitorContinueKind {
        structural(.catchClause, anchor: node.catchKeyword)
        walk(node.catchItems)
        nested(level + 1) { walk(node.body) }
        return .skipChildren
    }

    // MARK: - Loops

    override func visit(_ node: ForStmtSyntax) -> SyntaxVisitorContinueKind {
        structural(.loop, anchor: node.forKeyword)
        walk(node.pattern)
        walk(node.sequence)
        if let whereClause = node.whereClause {
            walk(whereClause)
        }
        nested(level + 1) { walk(node.body) }
        return .skipChildren
    }

    override func visit(_ node: WhileStmtSyntax) -> SyntaxVisitorContinueKind {
        structural(.loop, anchor: node.whileKeyword)
        scoreConditions(node.conditions)
        nested(level + 1) { walk(node.body) }
        return .skipChildren
    }

    override func visit(_ node: RepeatStmtSyntax) -> SyntaxVisitorContinueKind {
        structural(.loop, anchor: node.repeatKeyword)
        nested(level + 1) { walk(node.body) }
        walk(node.condition)
        return .skipChildren
    }

    // MARK: - Nesting without an increment

    override func visit(_ node: ClosureExprSyntax) -> SyntaxVisitorContinueKind {
        nested(level + 1, closures: closureLevel + 1) {
            if let signature = node.signature {
                walk(signature)
            }
            walk(node.statements)
        }
        return .skipChildren
    }

    override func visit(_ node: DeferStmtSyntax) -> SyntaxVisitorContinueKind {
        nested(level + 1) { walk(node.body) }
        return .skipChildren
    }

    // MARK: - Jumps and recursion

    override func visit(_ node: BreakStmtSyntax) -> SyntaxVisitorContinueKind {
        if node.label != nil {
            fundamental(.labeledJump, anchor: node.breakKeyword)
        }
        return .skipChildren
    }

    override func visit(_ node: ContinueStmtSyntax) -> SyntaxVisitorContinueKind {
        if node.label != nil {
            fundamental(.labeledJump, anchor: node.continueKeyword)
        }
        return .skipChildren
    }

    override func visit(_ node: FallThroughStmtSyntax) -> SyntaxVisitorContinueKind {
        if SwitchFacts.isOnlyStatement(node) == false {
            fundamental(.fallthroughJump, anchor: node.fallthroughKeyword)
        }
        return .skipChildren
    }

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        switch recursion?.classify(node) ?? .none {
        case .direct(let callee) where hasRecursion == false:
            hasRecursion = true
            fundamental(.recursion, anchor: callee)

        case .possible(let callee):
            items.append(factory.make(.cognitive, .possibleRecursion, amount: 0, anchor: callee))

        case .direct, .none:
            break
        }
        return .visitChildren
    }

    // MARK: - Logical sequences and ternaries

    override func visit(_ node: SequenceExprSyntax) -> SyntaxVisitorContinueKind {
        addRuns(LogicalSequences.tokens(of: node))
        walkSequence(node, at: level)
        return .skipChildren
    }

    override func visit(_ node: InfixOperatorExprSyntax) -> SyntaxVisitorContinueKind {
        scoreFoldedRoot(ExprSyntax(node))
    }

    override func visit(_ node: TernaryExprSyntax) -> SyntaxVisitorContinueKind {
        scoreFoldedRoot(ExprSyntax(node))
    }

    override func visit(_ node: IsExprSyntax) -> SyntaxVisitorContinueKind {
        scoreFoldedRoot(ExprSyntax(node))
    }

    override func visit(_ node: AsExprSyntax) -> SyntaxVisitorContinueKind {
        scoreFoldedRoot(ExprSyntax(node))
    }

    deinit {
        // Nothing to release beyond stored properties.
    }
}
