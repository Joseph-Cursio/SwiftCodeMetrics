//
//  ForCasePatterns.swift
//  SwiftCodeMetrics
//
//  Whether a `for case` pattern can fail, on the parse shapes swift-syntax
//  603.0.2 produces (Spec §4.2).
//

import SwiftSyntax

/// The irrefutable-pattern test for `for case`.
enum ForCasePatterns {
    /// Whether `pattern` matches every element.
    static func isIrrefutable(_ pattern: PatternSyntax) -> Bool {
        if let binding = pattern.as(ValueBindingPatternSyntax.self) {
            return isIrrefutable(binding.pattern)
        }
        if pattern.is(IdentifierPatternSyntax.self) || pattern.is(WildcardPatternSyntax.self) {
            return true
        }
        if let tuple = pattern.as(TuplePatternSyntax.self) {
            return tuple.elements.allSatisfy { isIrrefutable($0.pattern) }
        }
        if let expression = pattern.as(ExpressionPatternSyntax.self) {
            return isIrrefutable(expression.expression)
        }
        return false
    }

    /// Whether an expression inside a pattern matches everything.
    private static func isIrrefutable(_ expression: ExprSyntax) -> Bool {
        if expression.is(DiscardAssignmentExprSyntax.self) {
            return true
        }
        if let pattern = expression.as(PatternExprSyntax.self) {
            return isIrrefutable(pattern.pattern)
        }
        if let tuple = expression.as(TupleExprSyntax.self) {
            return tuple.elements.allSatisfy { isIrrefutable($0.expression) }
        }
        return false
    }
}
