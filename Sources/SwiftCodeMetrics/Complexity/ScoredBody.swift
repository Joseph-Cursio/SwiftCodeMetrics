//
//  ScoredBody.swift
//  SwiftCodeMetrics
//
//  Everything needed to score one record: the nodes of its body and the
//  facts about its declaration that the scores depend on.
//

import SwiftSyntax

/// The input to `ComplexityScorer`.
struct ScoredBody {
    /// The body's nodes, walked in order.
    let nodes: [Syntax]
    /// The record's kind.
    let kind: FunctionKind
    /// The recursion check, for an ordinary `func`.
    let recursion: RecursionMatcher?
    /// The builder hint.
    let hint: ResultBuilderHint?
    /// Whether the declaration has unexpected or missing syntax.
    let hasSyntaxErrors: Bool
}
