//
//  GoldenBreakdownTests.swift
//  SwiftCodeMetricsTests
//
//  Spec §16 v0.1: the anchor line of every item in every fixture, checked
//  against a reviewed text file. To accept a deliberate change, run with
//  `SWIFTCODEMETRICS_UPDATE_GOLDEN=1` and review the diff of
//  `Golden/Breakdowns.txt`.
//

import Foundation
import SwiftCodeMetrics
import Testing

@Suite("Golden breakdowns")
struct GoldenBreakdownTests {
    private static let sourceCopy = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Golden/Breakdowns.txt")

    /// One fixture's records and items as text.
    private static func render(_ fixture: String) -> String {
        var lines = ["== \(fixture)"]
        for record in Fixtures.analysis(fixture).functions {
            let scores = record.complexity
            let parent = record.parentID.map(String.init) ?? "-"
            lines.append("\(record.id) \(record.kind.rawValue) \(record.name) parent=\(parent)")
            lines.append("  key \(record.key)")
            lines.append(
                "  C \(scores.cognitive) D \(scores.decisionCount) SL \(scores.swiftLintCompatible)"
                    + " maxNesting \(scores.maxNesting) hint \(scores.resultBuilderHint.map { "\($0)" } ?? "none")"
            )
            for item in scores.items {
                let position = "\(item.line ?? 0):\(item.column ?? 0)"
                let nesting = item.nesting == 0 ? "" : " nesting \(item.nesting) closures \(item.closureNesting)"
                lines.append("  \(item.metric.rawValue) \(item.rule.rawValue) \(item.amount) @\(position)\(nesting)")
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    @Test("every record's scores and items match Golden/Breakdowns.txt")
    func breakdowns() throws {
        let actual = Fixtures.names.map(Self.render).joined(separator: "\n")
        if ProcessInfo.processInfo.environment["SWIFTCODEMETRICS_UPDATE_GOLDEN"] == "1" {
            try actual.write(to: Self.sourceCopy, atomically: true, encoding: .utf8)
        }
        let bundled = Fixtures.directory.deletingLastPathComponent().appendingPathComponent("Golden/Breakdowns.txt")
        let expected = try String(contentsOf: bundled, encoding: .utf8)

        #expect(actual == expected, "breakdowns differ; rerun with SWIFTCODEMETRICS_UPDATE_GOLDEN=1 and review")
    }
}
