//
//  FirstFunction.swift
//  SwiftCodeMetricsTests
//
//  Finds the first `func` in a tree, for the declaration-form tests.
//

import SwiftSyntax

/// Remembers the first function declaration it visits.
final class FirstFunction: SyntaxVisitor {
    /// The first `func` found.
    private(set) var found: FunctionDeclSyntax?

    /// Creates a visitor.
    init() {
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        if found == nil {
            found = node
        }
        return .skipChildren
    }

    deinit {
        // Nothing to release beyond stored properties.
    }
}
