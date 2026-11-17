//
//  WorkedExampleTests.swift
//  SwiftCodeMetricsTests
//
//  Spec §16 v0.1 golden tests: every worked example in §6 and the §4.2
//  check, with C, D, mccabe and SL as the spec states them, and the line
//  of every cognitive item in the spec's tables.
//

import SwiftCodeMetrics
import Testing

@Suite("Worked examples (Spec §6)")
struct WorkedExampleTests {
    private static let examples: [WorkedExample] = WorkedExampleTable.all

    @Test("C, D, mccabe and SL match the spec", arguments: examples)
    func scores(_ example: WorkedExample) throws {
        let analysis = Fixtures.analysis(example.fixture)
        let record = try #require(Fixtures.record(example.function, in: analysis))

        #expect(record.complexity.cognitive == example.scores.cognitive)
        #expect(record.complexity.decisionCount == example.scores.decisions)
        #expect(record.complexity.mccabe == example.scores.decisions + 1)
        #expect(record.complexity.swiftLintCompatible == example.scores.swiftLint)
    }

    @Test("cognitive items sit on the lines the spec's tables give", arguments: examples.filter { $0.items != nil })
    func cognitiveLines(_ example: WorkedExample) throws {
        let analysis = Fixtures.analysis(example.fixture)
        let record = try #require(Fixtures.record(example.function, in: analysis))

        #expect(example.expectedItems.count == (example.items ?? "").split(separator: ",").count, "table parses")
        #expect(ExpectedItem.cognitive(of: record) == example.expectedItems)
    }

    @Test("6.9 is an opaque-result builder body that SwiftLint does not score")
    func swiftUIBody() throws {
        let record = try #require(Fixtures.record("body.get", in: Fixtures.analysis("Example6_9.swift")))

        #expect(record.complexity.resultBuilderHint == .opaqueResult("View"))
        #expect(record.complexity.swiftLintScoresKind == false)
        #expect(record.kind == .computedGetter)
        let closureNesting = record.complexity.items.filter { $0.metric == .cognitive }.map(\.closureNesting)
        #expect(closureNesting.reduce(0, +) == 5)
    }

    @Test("6.13 with decisionCountIgnoresTrivialSwitches scores the switch as one decision")
    func trivialSwitch() throws {
        var options = MetricsOptions()
        options.complexity.decisionCountIgnoresTrivialSwitches = true
        let analysis = Fixtures.analysis("Example6_13.swift", options: options)
        let record = try #require(Fixtures.record("shippingCost(for:)", in: analysis))

        #expect(record.complexity.decisionCount == 3)
        #expect(record.complexity.items.contains { $0.rule == .trivialSwitch && $0.line == 2 })
    }

    @Test("6.16's nested function is its own record, linked to its parent")
    func nestedFunction() throws {
        let analysis = Fixtures.analysis("Example6_16.swift")
        let render = try #require(Fixtures.record("render(_:)", in: analysis))
        let cell = try #require(Fixtures.record("cell(_:)", in: analysis))

        #expect(cell.parentID == render.id)
        #expect(cell.parentKey == render.key)
        #expect(cell.key.description == "Lib::func render(_: [Row]) -> String / func cell(_: Int?) -> String")
    }
}
