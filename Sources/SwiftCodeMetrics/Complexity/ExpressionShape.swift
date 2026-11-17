//
//  ExpressionShape.swift
//  SwiftCodeMetrics
//
//  Looks through wrappers that don't change an expression's logic: plain
//  parentheses and the effect and ownership keywords (Spec §3.2 row 50).
//

import SwiftSyntax

/// Shape questions about expressions.
enum ExpressionShape {
    /// Removes one-element unlabelled parentheses and `try`, `await`,
    /// `unsafe`, `consume`, `copy` and `borrow`, until none is left.
    static func unwrap(_ expression: ExprSyntax) -> ExprSyntax {
        var current = expression
        while let inner = wrapped(current) {
            current = inner
        }
        return current
    }

    /// Whether a folded node joins the token list of the node around it
    /// (Spec §3.5.1).
    static func isSpliceable(_ expression: ExprSyntax) -> Bool {
        expression.is(InfixOperatorExprSyntax.self)
            || expression.is(TernaryExprSyntax.self)
            || expression.is(IsExprSyntax.self)
            || expression.is(AsExprSyntax.self)
    }

    /// The expression inside one wrapper, or nil.
    private static func wrapped(_ expression: ExprSyntax) -> ExprSyntax? {
        if let tuple = expression.as(TupleExprSyntax.self) {
            guard tuple.elements.count == 1, let element = tuple.elements.first, element.label == nil else {
                return nil
            }
            return element.expression
        }
        if let wrapper = expression.as(TryExprSyntax.self) {
            return wrapper.expression
        }
        if let wrapper = expression.as(AwaitExprSyntax.self) {
            return wrapper.expression
        }
        if let wrapper = expression.as(UnsafeExprSyntax.self) {
            return wrapper.expression
        }
        if let wrapper = expression.as(ConsumeExprSyntax.self) {
            return wrapper.expression
        }
        if let wrapper = expression.as(CopyExprSyntax.self) {
            return wrapper.expression
        }
        return expression.as(BorrowExprSyntax.self)?.expression
    }
}
