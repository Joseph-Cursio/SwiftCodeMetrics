//
//  ComplexityScorer.swift
//  SwiftCodeMetrics
//
//  Runs the three visitors over one body and assembles its scores.
//

import SwiftSyntax

/// Scores bodies with one set of options.
struct ComplexityScorer {
    /// The options.
    let options: ComplexityOptions
    /// Builds items.
    let factory: IncrementFactory

    /// Items in source order; items at one anchor keep their order.
    private static func ordered(_ items: [Increment]) -> [Increment] {
        items.enumerated()
            .sorted { ($0.element.utf8Offset, $0.offset) < ($1.element.utf8Offset, $1.offset) }
            .map(\.element)
    }

    /// The sum of the amounts.
    private static func sum(_ items: [Increment]) -> Int {
        items.reduce(0) { $0 + $1.amount }
    }

    /// The scores of `body`.
    func score(_ body: ScoredBody) -> ComplexityScores {
        let cognitive = CognitiveVisitor(factory: factory, recursion: options.detectRecursion ? body.recursion : nil)
        let decision = DecisionVisitor(
            factory: factory,
            ignoresTrivialSwitches: options.decisionCountIgnoresTrivialSwitches
        )
        let swiftLint = SwiftLintVisitor(
            factory: factory,
            ignoresCaseStatements: options.swiftLintIgnoresCaseStatements
        )
        for node in body.nodes {
            cognitive.walk(node)
            decision.walk(node)
            swiftLint.walk(node)
        }
        let items = Self.ordered(cognitive.items) + Self.ordered(decision.items) + Self.ordered(swiftLint.items)
        return ComplexityScores(
            cognitive: Self.sum(cognitive.items),
            decisionCount: decision.total,
            swiftLintCompatible: Self.sum(swiftLint.items),
            swiftLintScoresKind: body.kind.swiftLintScoresKind,
            maxNesting: cognitive.maxNesting,
            resultBuilderHint: body.hint,
            hasSyntaxErrors: body.hasSyntaxErrors,
            items: items
        )
    }
}
