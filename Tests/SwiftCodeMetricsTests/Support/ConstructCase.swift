//
//  ConstructCase.swift
//  SwiftCodeMetricsTests
//
//  One row of the construct tables (Spec §3.2, §4.2) as a snippet with
//  its expected scores.
//

/// A snippet and the scores of one of its records.
struct ConstructCase: CustomStringConvertible, Sendable {
    /// The table row or rows it covers, such as "3.2 #16".
    let rows: String
    /// A whole file.
    let source: String
    /// The record to check.
    let function: String
    /// The expected scores.
    let expected: ExpectedScores

    var description: String {
        rows
    }

    /// A case for the record `f()`.
    init(_ rows: String, _ source: String, expect: String) {
        self.init(rows, source, function: "f()", expect: expect)
    }

    /// A case for the record `function`.
    init(_ rows: String, _ source: String, function: String, expect: String) {
        self.rows = rows
        self.source = source
        self.function = function
        self.expected = ExpectedScores(expect)
    }
}
