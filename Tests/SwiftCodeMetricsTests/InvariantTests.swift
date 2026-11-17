//
//  InvariantTests.swift
//  SwiftCodeMetricsTests
//
//  Spec §16 v0.1: breakdowns sum to their scores, folded trees score like
//  unfolded ones, and results survive an encode and decode round trip.
//

import Foundation
import SwiftCodeMetrics
import Testing

@Suite("Invariants")
struct InvariantTests {
    @Test("each metric's items sum to its score", arguments: Fixtures.names)
    func breakdownSums(_ fixture: String) {
        for record in Fixtures.analysis(fixture).functions {
            let scores = record.complexity
            #expect(sum(scores.items, .cognitive) == scores.cognitive, "\(record.name)")
            #expect(sum(scores.items, .decision) == scores.decisionCount, "\(record.name)")
            #expect(sum(scores.items, .swiftLint) == scores.swiftLintCompatible, "\(record.name)")
        }
    }

    @Test("a tree folded with SwiftOperators gives the same scores and items", arguments: Fixtures.names)
    func foldedInput(_ fixture: String) {
        let unfolded = Fixtures.analysis(fixture).functions
        let folded = Fixtures.analysis(fixture, folded: true).functions

        #expect(folded.map(\.name) == unfolded.map(\.name))
        for (plain, foldedRecord) in zip(unfolded, folded) {
            #expect(foldedRecord.complexity == plain.complexity, "\(plain.name)")
        }
    }

    @Test("a FunctionAnalysis survives an encode and decode round trip", arguments: Fixtures.names)
    func codable(_ fixture: String) throws {
        let analysis = Fixtures.analysis(fixture)
        let data = try JSONEncoder().encode(analysis)

        #expect(try JSONDecoder().decode(FunctionAnalysis.self, from: data) == analysis)
    }

    @Test("folding gives the same logical runs for a ternary inside parentheses (Spec §3.5.1)")
    func foldedTernaryRoot() throws {
        let source = "func f() -> Bool { (x && y ? b : c && z) && d }"
        let plain = try #require(Fixtures.analysis(source: source).functions.first)
        let folded = try #require(Fixtures.analysis(source: source, folded: true).functions.first)

        #expect(plain.complexity.cognitive == 3)
        #expect(folded.complexity.cognitive == plain.complexity.cognitive)
    }

    @Test("folded casts splice their operand")
    func foldedCast() throws {
        let source = "func f() -> Bool { (a && b) as Bool && c }"
        let plain = try #require(Fixtures.analysis(source: source).functions.first)
        let folded = try #require(Fixtures.analysis(source: source, folded: true).functions.first)

        #expect(plain.complexity.cognitive == 1)
        #expect(folded.complexity.cognitive == 1)
    }

    private func sum(_ items: [Increment], _ metric: Increment.Metric) -> Int {
        items.filter { $0.metric == metric }.reduce(0) { $0 + $1.amount }
    }
}
