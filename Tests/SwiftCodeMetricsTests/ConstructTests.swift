//
//  ConstructTests.swift
//  SwiftCodeMetricsTests
//
//  Spec §16 v0.1 construct coverage: every row of the §3.2 construct table
//  and the §4.2 decision table has at least one case.
//

import SwiftCodeMetrics
import Testing

@Suite("Constructs (Spec §3.2, §4.2)")
struct ConstructTests {
    @Test("each construct scores as its table row says", arguments: ConstructTable.all)
    func construct(_ example: ConstructCase) throws {
        let analysis = Fixtures.analysis(source: example.source)
        let record = try #require(Fixtures.record(example.function, in: analysis), "\(analysis.functions.map(\.name))")

        let actual = ExpectedScores(
            "C \(record.complexity.cognitive) D \(record.complexity.decisionCount) "
                + "SL \(record.complexity.swiftLintCompatible)"
        )
        #expect(actual == example.expected)
    }

    @Test("a lookup-table switch, fallthrough-only arm included, costs 1 with the lint option")
    func trivialSwitchWithFallthrough() throws {
        let source = "func f() -> Int { switch x { case 0: fallthrough; case 1: return 1; "
            + "case 2: return 2; default: return 3 } }"
        var options = MetricsOptions()
        options.complexity.decisionCountIgnoresTrivialSwitches = true

        #expect(try decisions(source) == 2)
        #expect(try decisions(source, options) == 1)
    }

    @Test("a where clause stops a switch being trivial")
    func whereStopsTrivial() throws {
        let source = "func f() -> Int { switch x { case 1 where a: return 1; case 2: return 2; default: return 3 } }"
        var options = MetricsOptions()
        options.complexity.decisionCountIgnoresTrivialSwitches = true

        #expect(try decisions(source, options) == 3)
    }

    @Test("builder hints: attribute first, then a known some-P result")
    func builderHints() {
        let analysis = Fixtures.analysis(source: """
        @SwiftUI.ViewBuilder func a() -> some View { A() }
        func b() -> some Scene & Sendable { S() }
        func c() -> some Collection { [] }
        """)

        #expect(Fixtures.record("a()", in: analysis)?.complexity.resultBuilderHint == .attribute("ViewBuilder"))
        #expect(Fixtures.record("b()", in: analysis)?.complexity.resultBuilderHint == .opaqueResult("Scene"))
        #expect(Fixtures.record("c()", in: analysis)?.complexity.resultBuilderHint == nil)
    }

    @Test("the maximum nesting level is recorded")
    func maxNesting() {
        let analysis = Fixtures.analysis(source: """
        func f() { if a { xs.map { if b {} } } }
        func g() { if c {} }
        func h() {}
        """)

        #expect(Fixtures.record("f()", in: analysis)?.complexity.maxNesting == 3)
        #expect(Fixtures.record("g()", in: analysis)?.complexity.maxNesting == 1)
        #expect(Fixtures.record("h()", in: analysis)?.complexity.maxNesting == 0)
    }

    @Test("a function with broken syntax is flagged")
    func syntaxErrors() {
        let analysis = Fixtures.analysis(source: "func f() { if a { }\nfunc g() { let x = }")

        #expect(analysis.functions.map(\.complexity.hasSyntaxErrors).contains(true))
    }

    private func decisions(_ source: String) throws -> Int {
        try decisions(source, MetricsOptions())
    }

    private func decisions(_ source: String, _ options: MetricsOptions) throws -> Int {
        try #require(Fixtures.analysis(source: source, options: options).functions.first).complexity.decisionCount
    }
}
