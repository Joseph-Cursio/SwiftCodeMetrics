//
//  DecisionVisitor.swift
//  SwiftCodeMetrics
//
//  The decision count (Spec §4.1–4.2): run-time branch points, base 0.
//  `#if` takes the clause with the most decisions, so the items of the
//  chosen clauses still sum to the score.
//

import SwiftSyntax

/// Scores one function's own body for the decision count.
final class DecisionVisitor: OwnBodyVisitor {
    /// The breakdown so far.
    var items: [Increment] = []

    /// Builds items.
    let factory: IncrementFactory
    /// Whether lookup-table switches cost 1 (Spec §4.2).
    let ignoresTrivialSwitches: Bool

    /// The sum of the items' amounts.
    var total: Int {
        items.reduce(0) { $0 + $1.amount }
    }

    /// Creates a visitor.
    init(factory: IncrementFactory, ignoresTrivialSwitches: Bool) {
        self.factory = factory
        self.ignoresTrivialSwitches = ignoresTrivialSwitches
        super.init()
    }

    override func visit(_ node: IfExprSyntax) -> SyntaxVisitorContinueKind {
        let isElseIf = node.parent?.as(IfExprSyntax.self)?.elseBody?.as(IfExprSyntax.self)?.id == node.id
        add(isElseIf ? .elseIf : .ifStatement, anchor: node.ifKeyword)
        addExtraConditions(node.conditions)
        return .visitChildren
    }

    override func visit(_ node: GuardStmtSyntax) -> SyntaxVisitorContinueKind {
        add(.guardStatement, anchor: node.guardKeyword)
        addExtraConditions(node.conditions)
        return .visitChildren
    }

    override func visit(_ node: WhileStmtSyntax) -> SyntaxVisitorContinueKind {
        add(.loop, anchor: node.whileKeyword)
        addExtraConditions(node.conditions)
        return .visitChildren
    }

    override func visit(_ node: RepeatStmtSyntax) -> SyntaxVisitorContinueKind {
        add(.loop, anchor: node.repeatKeyword)
        return .visitChildren
    }

    override func visit(_ node: ForStmtSyntax) -> SyntaxVisitorContinueKind {
        add(.loop, anchor: node.forKeyword)
        if let caseKeyword = node.caseKeyword, ForCasePatterns.isIrrefutable(node.pattern) == false {
            add(.forCasePattern, anchor: caseKeyword)
        }
        return .visitChildren
    }

    /// `WhereClauseSyntax` appears only on case items, `for` and catch
    /// items, exactly the three positions D counts.
    override func visit(_ node: WhereClauseSyntax) -> SyntaxVisitorContinueKind {
        add(.whereClause, anchor: node.whereKeyword)
        return .visitChildren
    }

    override func visit(_ node: CatchClauseSyntax) -> SyntaxVisitorContinueKind {
        add(.catchClause, anchor: node.catchKeyword)
        return .visitChildren
    }

    override func visit(_ node: UnresolvedTernaryExprSyntax) -> SyntaxVisitorContinueKind {
        add(.ternary, anchor: node.questionMark)
        return .visitChildren
    }

    override func visit(_ node: TernaryExprSyntax) -> SyntaxVisitorContinueKind {
        add(.ternary, anchor: node.questionMark)
        return .visitChildren
    }

    override func visit(_ node: BinaryOperatorExprSyntax) -> SyntaxVisitorContinueKind {
        switch node.operator.text {
        case "&&", "||":
            add(.logicalOperator, anchor: node.operator)

        case "??":
            add(.nilCoalescing, anchor: node.operator)

        default:
            break
        }
        return .skipChildren
    }

    override func visit(_ node: SwitchExprSyntax) -> SyntaxVisitorContinueKind {
        walk(node.subject)
        let summary = summarize(node.cases)
        if ignoresTrivialSwitches, isTrivial(node.cases, arms: summary.arms) {
            add(.trivialSwitch, anchor: node.switchKeyword)
        } else if summary.arms > 1 {
            add(.switchArms, amount: summary.arms - 1, anchor: node.switchKeyword)
        }
        items += summary.items
        return .skipChildren
    }

    /// One build runs one clause, so take the clause with the most
    /// decisions; ties go to the first (Spec §4.2).
    override func visit(_ node: IfConfigDeclSyntax) -> SyntaxVisitorContinueKind {
        guard node.parent?.is(AttributeListSyntax.self) == false else {
            return .skipChildren
        }
        var best: [Increment] = []
        var bestTotal = 0
        for clause in node.clauses {
            guard let elements = clause.elements else {
                continue
            }
            let visitor = child()
            visitor.walk(elements)
            if visitor.total > bestTotal {
                best = visitor.items
                bestTotal = visitor.total
            }
        }
        items += best
        return .skipChildren
    }

    deinit {
        // Nothing to release beyond stored properties.
    }
}
