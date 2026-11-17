//
//  CognitiveVisitor+Structure.swift
//  SwiftCodeMetrics
//
//  How the cognitive visitor walks children at the right level: if chains,
//  condition lists, case lists, `#if`, sequences and folded expressions.
//

import SwiftSyntax

extension CognitiveVisitor {
    /// An `if` and its `else if` chain, which is flat (Spec §3.3).
    func scoreIf(_ node: IfExprSyntax, isElseIf: Bool) {
        if isElseIf {
            hybrid(.elseIf, anchor: node.ifKeyword)
        } else {
            structural(.ifStatement, anchor: node.ifKeyword)
        }
        scoreConditions(node.conditions)
        nested(level + 1) { walk(node.body) }
        switch node.elseBody {
        case .ifExpr(let elseIf):
            scoreIf(elseIf, isElseIf: true)

        case .codeBlock(let block):
            if let elseKeyword = node.elseKeyword {
                hybrid(.elseClause, anchor: elseKeyword)
            }
            nested(level + 1) { walk(block) }

        case nil:
            break
        }
    }

    /// A condition list costs 1 once when it has two or more elements.
    func scoreConditions(_ conditions: ConditionElementListSyntax) {
        if conditions.count > 1, let comma = conditions.first?.trailingComma {
            fundamental(.conditionList, anchor: comma)
        }
        walk(conditions)
    }

    /// Case labels sit at the current level, case bodies at `bodyLevel`. A
    /// `#if` in the case list sits at `bodyLevel` (Spec §3.3).
    func walkCases(_ cases: SwitchCaseListSyntax, bodyLevel: Int) {
        for element in cases {
            switch element {
            case .switchCase(let switchCase):
                walk(switchCase.label)
                nested(bodyLevel) { walk(switchCase.statements) }

            case .ifConfigDecl(let ifConfig):
                nested(bodyLevel) { scoreIfConfig(ifConfig) }
            }
        }
    }

    /// `#if` is structural, `#elseif` and `#else` hybrid; every clause is
    /// read, so every clause counts. Conditions are never walked.
    func scoreIfConfig(_ node: IfConfigDeclSyntax) {
        for (index, clause) in node.clauses.enumerated() {
            if index == 0 {
                structural(.conditionalCompilation, anchor: clause.poundKeyword)
            } else {
                hybrid(.conditionalCompilationElse, anchor: clause.poundKeyword)
            }
            guard let elements = clause.elements else {
                continue
            }
            if case .switchCases(let cases) = elements {
                walkCases(cases, bodyLevel: level + 1)
            } else {
                nested(level + 1) { walk(elements) }
            }
        }
    }

    /// The elements of an unfolded sequence at level `base`: ternary *k* of
    /// a segment sits at `base + k − 1`, and what follows it at `base + k`
    /// (Spec §3.5.4). Operands that unwrap to sequences are spliced.
    func walkSequence(_ sequence: SequenceExprSyntax, at base: Int) {
        var ternaries = 0
        for element in sequence.elements {
            if let ternary = element.as(UnresolvedTernaryExprSyntax.self) {
                ternaries += 1
                structural(.ternary, anchor: ternary.questionMark, nesting: base + ternaries - 1)
                nested(base + ternaries) { walk(ternary.thenExpression) }
            } else if element.is(AssignmentExprSyntax.self) || element.is(ArrowExprSyntax.self) {
                ternaries = 0
            } else if element.is(BinaryOperatorExprSyntax.self) == false {
                walkOperand(element, at: base + ternaries)
            }
        }
    }

    /// One sequence operand.
    func walkOperand(_ operand: ExprSyntax, at operandLevel: Int) {
        if let inner = ExpressionShape.unwrap(operand).as(SequenceExprSyntax.self) {
            walkSequence(inner, at: operandLevel)
        } else {
            nested(operandLevel) { walk(operand) }
        }
    }

    /// A folded root: its logical runs, then its contents (Spec §3.5.1).
    func scoreFoldedRoot(_ node: ExprSyntax) -> SyntaxVisitorContinueKind {
        addRuns(LogicalSequences.tokens(ofFolded: node))
        walkFolded(node, at: level)
        return .skipChildren
    }

    /// A folded spliceable node. Ternaries nest by tree structure.
    func walkFolded(_ node: ExprSyntax, at nodeLevel: Int) {
        if let infix = node.as(InfixOperatorExprSyntax.self) {
            walkFoldedOperand(infix.leftOperand, at: nodeLevel)
            walkFoldedOperand(infix.rightOperand, at: nodeLevel)
        } else if let ternary = node.as(TernaryExprSyntax.self) {
            structural(.ternary, anchor: ternary.questionMark, nesting: nodeLevel)
            walkFoldedOperand(ternary.condition, at: nodeLevel)
            nested(nodeLevel + 1) { walk(ternary.thenExpression) }
            walkFoldedOperand(ternary.elseExpression, at: nodeLevel + 1)
        } else if let cast = node.as(IsExprSyntax.self) {
            walkFoldedOperand(cast.expression, at: nodeLevel)
        } else if let cast = node.as(AsExprSyntax.self) {
            walkFoldedOperand(cast.expression, at: nodeLevel)
        }
    }

    /// One folded operand: spliced if spliceable, else walked as a root.
    func walkFoldedOperand(_ operand: ExprSyntax, at operandLevel: Int) {
        let unwrapped = ExpressionShape.unwrap(operand)
        if ExpressionShape.isSpliceable(unwrapped) {
            walkFolded(unwrapped, at: operandLevel)
        } else {
            nested(operandLevel) { walk(operand) }
        }
    }

    /// One fundamental item per run of like operators.
    func addRuns(_ tokens: [LogicalToken]) {
        for start in LogicalSequences.runStarts(tokens) {
            fundamental(.logicalSequence, anchor: start)
        }
    }

    /// Runs `body` at `newLevel`, recording it as a nesting level reached.
    func nested(_ newLevel: Int, _ body: () -> Void) {
        nested(newLevel, closures: closureLevel, body)
    }

    /// Runs `body` at `newLevel`, with `closures` of it from closures.
    func nested(_ newLevel: Int, closures: Int, _ body: () -> Void) {
        let saved = (level, closureLevel)
        level = newLevel
        closureLevel = closures
        maxNesting = max(maxNesting, newLevel)
        body()
        (level, closureLevel) = saved
    }

    /// +1 plus the current nesting level.
    func structural(_ rule: Increment.Rule, anchor: TokenSyntax) {
        structural(rule, anchor: anchor, nesting: level)
    }

    /// +1 plus `nestingPart`.
    func structural(_ rule: Increment.Rule, anchor: TokenSyntax, nesting nestingPart: Int) {
        items.append(factory.structural(
            rule,
            anchor: anchor,
            nesting: nestingPart,
            closureNesting: min(closureLevel, nestingPart)
        ))
    }

    /// +1, raising nesting for its body.
    func hybrid(_ rule: Increment.Rule, anchor: TokenSyntax) {
        items.append(factory.make(.cognitive, rule, amount: 1, anchor: anchor))
    }

    /// +1 flat.
    func fundamental(_ rule: Increment.Rule, anchor: TokenSyntax) {
        items.append(factory.make(.cognitive, rule, amount: 1, anchor: anchor))
    }
}
