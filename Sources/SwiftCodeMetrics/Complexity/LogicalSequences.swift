//
//  LogicalSequences.swift
//  SwiftCodeMetrics
//
//  Token lists for runs of `&&` and `||` (Spec §3.5), on unfolded
//  `SequenceExprSyntax` and on trees folded by SwiftOperators. Both give the
//  same lists, so folding never changes a score.
//

import SwiftSyntax

/// Builds token lists and finds the start of each run.
enum LogicalSequences {
    /// The operator that starts each run of like operators.
    static func runStarts(_ tokens: [LogicalToken]) -> [TokenSyntax] {
        var starts: [TokenSyntax] = []
        var previous: String?
        for token in tokens {
            switch token {
            case .boundary:
                previous = nil

            case let .logical(text, operatorToken):
                if text != previous {
                    starts.append(operatorToken)
                }
                previous = text
            }
        }
        return starts
    }

    /// The token list of an unfolded root sequence, splicing operands that
    /// unwrap to sequences.
    static func tokens(of sequence: SequenceExprSyntax) -> [LogicalToken] {
        var tokens: [LogicalToken] = []
        for element in sequence.elements {
            if let binary = element.as(BinaryOperatorExprSyntax.self) {
                tokens += logical(binary.operator)
            } else if isBoundary(element) {
                tokens.append(.boundary)
            } else if let inner = ExpressionShape.unwrap(element).as(SequenceExprSyntax.self) {
                tokens += self.tokens(of: inner)
            }
        }
        return tokens
    }

    /// The token list of a folded root: an infix, ternary or cast node.
    static func tokens(ofFolded expression: ExprSyntax) -> [LogicalToken] {
        if let infix = expression.as(InfixOperatorExprSyntax.self) {
            return operandTokens(infix.leftOperand) + operatorTokens(infix.operator) + operandTokens(infix.rightOperand)
        }
        if let ternary = expression.as(TernaryExprSyntax.self) {
            return operandTokens(ternary.condition) + [.boundary] + operandTokens(ternary.elseExpression)
        }
        if let cast = expression.as(IsExprSyntax.self) {
            return operandTokens(cast.expression)
        }
        if let cast = expression.as(AsExprSyntax.self) {
            return operandTokens(cast.expression)
        }
        return []
    }

    /// Whether an unfolded element ends a run: a ternary, `=` or `->`.
    static func isBoundary(_ element: ExprSyntax) -> Bool {
        element.is(UnresolvedTernaryExprSyntax.self)
            || element.is(AssignmentExprSyntax.self)
            || element.is(ArrowExprSyntax.self)
    }

    /// A folded operand's tokens: its own if it is spliceable, else none.
    private static func operandTokens(_ operand: ExprSyntax) -> [LogicalToken] {
        let unwrapped = ExpressionShape.unwrap(operand)
        return ExpressionShape.isSpliceable(unwrapped) ? tokens(ofFolded: unwrapped) : []
    }

    /// A folded operator's tokens.
    private static func operatorTokens(_ expression: ExprSyntax) -> [LogicalToken] {
        if let binary = expression.as(BinaryOperatorExprSyntax.self) {
            return logical(binary.operator)
        }
        return expression.is(AssignmentExprSyntax.self) || expression.is(ArrowExprSyntax.self) ? [.boundary] : []
    }

    /// `&&` and `||` emit themselves; every other operator emits nothing.
    private static func logical(_ token: TokenSyntax) -> [LogicalToken] {
        token.text == "&&" || token.text == "||" ? [.logical(text: token.text, token: token)] : []
    }
}
