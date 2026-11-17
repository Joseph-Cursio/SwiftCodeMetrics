//
//  ExpectedScores.swift
//  SwiftCodeMetricsTests
//
//  Expected C, D and SL written as "C 6 D 6 SL 3".
//

/// The three scores a case expects.
struct ExpectedScores: Sendable, Equatable {
    /// Cognitive complexity.
    let cognitive: Int
    /// The decision count.
    let decisions: Int
    /// The SwiftLint-compatible count.
    let swiftLint: Int

    /// Reads "C n D n SL n"; a missing value reads as -1, which no score equals.
    init(_ text: String) {
        var values: [String: Int] = [:]
        let words = text.split(separator: " ").map(String.init)
        for (name, value) in zip(words, words.dropFirst()) {
            values[name] = Int(value)
        }
        cognitive = values["C"] ?? -1
        decisions = values["D"] ?? -1
        swiftLint = values["SL"] ?? -1
    }
}
