//
//  ComplexityScores.swift
//  SwiftCodeMetrics
//
//  The three Part A scores of one function, with their breakdown.
//

/// Cognitive complexity, the decision count and the SwiftLint-compatible count.
public struct ComplexityScores: Sendable, Codable, Hashable {
    /// Cognitive complexity (C, Spec §3).
    public let cognitive: Int
    /// The decision count (D, Spec §4), base 0.
    public let decisionCount: Int
    /// The SwiftLint-compatible count (SL, Spec §4.3).
    public let swiftLintCompatible: Int
    /// Whether SwiftLint scores this kind of function: true only for `func` and `init`.
    public let swiftLintScoresKind: Bool
    /// The highest level any construct gives its contents, closures and `defer` included.
    public let maxNesting: Int
    /// Why the body looks like a result-builder body (Spec §5); nil when it doesn't.
    public let resultBuilderHint: ResultBuilderHint?
    /// Whether the function's source contains unexpected or missing syntax.
    public let hasSyntaxErrors: Bool
    /// Every increment behind the three scores.
    public let items: [Increment]

    /// McCabe's v(G): the decision count plus 1. Derived, not encoded.
    public var mccabe: Int {
        decisionCount + 1
    }
}
