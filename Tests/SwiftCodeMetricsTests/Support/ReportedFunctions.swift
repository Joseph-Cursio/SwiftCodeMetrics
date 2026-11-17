//
//  ReportedFunctions.swift
//  SwiftCodeMetricsTests
//
//  The functions SwiftLint scores, with the token it reports at.
//

import SwiftSyntax

/// Finds every `func` and `init` with a body.
final class ReportedFunctions: SyntaxVisitor {
    /// Each function's start offset and report position.
    private(set) var targets: [(start: Int, token: AbsolutePosition)] = []

    /// Creates a visitor.
    init() {
        super.init(viewMode: .sourceAccurate)
    }

    /// The scored functions in `tree`.
    static func collect(_ tree: SourceFileSyntax) -> [(start: Int, token: AbsolutePosition)] {
        let visitor = ReportedFunctions()
        visitor.walk(tree)
        return visitor.targets
    }

    override func visitPost(_ node: FunctionDeclSyntax) {
        guard node.body != nil else {
            return
        }
        let modifier = node.modifiers.first { modifier in
            modifier.name.tokenKind == .keyword(.static) || modifier.name.tokenKind == .keyword(.class)
        }
        let token = modifier?.name ?? node.funcKeyword
        targets.append((node.positionAfterSkippingLeadingTrivia.utf8Offset, token.positionAfterSkippingLeadingTrivia))
    }

    override func visitPost(_ node: InitializerDeclSyntax) {
        guard node.body != nil else {
            return
        }
        let start = node.positionAfterSkippingLeadingTrivia.utf8Offset
        targets.append((start, node.initKeyword.positionAfterSkippingLeadingTrivia))
    }

    deinit {
        // Nothing to release beyond stored properties.
    }
}
