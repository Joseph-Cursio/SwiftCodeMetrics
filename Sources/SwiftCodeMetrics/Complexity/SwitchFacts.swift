//
//  SwitchFacts.swift
//  SwiftCodeMetrics
//
//  Questions about `switch` cases that more than one metric asks.
//

import SwiftSyntax

/// Facts about switch cases.
enum SwitchFacts {
    /// Whether `node` is its case's only statement (Spec §3.2 rows 25–26).
    static func isOnlyStatement(_ node: FallThroughStmtSyntax) -> Bool {
        var current = node.parent
        while let ancestor = current {
            if let switchCase = ancestor.as(SwitchCaseSyntax.self) {
                return switchCase.statements.count == 1
                    && switchCase.statements.first?.item.as(FallThroughStmtSyntax.self)?.id == node.id
            }
            current = ancestor.parent
        }
        return false
    }

    /// Whether a case's only statement is `fallthrough`: it merges labels
    /// rather than adding an arm (Spec §4.2).
    static func isFallthroughOnly(_ switchCase: SwitchCaseSyntax) -> Bool {
        switchCase.statements.count == 1
            && switchCase.statements.first?.item.is(FallThroughStmtSyntax.self) == true
    }

    /// Whether any case item of `switchCase` has a `where` clause.
    static func hasWhere(_ switchCase: SwitchCaseSyntax) -> Bool {
        guard case .case(let label) = switchCase.label else {
            return false
        }
        return label.caseItems.contains { $0.whereClause != nil }
    }
}
