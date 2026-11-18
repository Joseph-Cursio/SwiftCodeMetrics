//
//  ReviewRoundFourTests.swift
//  SwiftCodeMetricsTests
//
//  Regression tests from the fourth review round: `#if` clauses at file
//  scope, binding patterns, typealias variants, backticked names and
//  top-level code.
//

import SwiftCodeMetrics
import Testing

@Suite("v0.2 review regressions, round 4")
struct ReviewRoundFourTests {
    @Test("declarations in a top-level #if clause stay globals, free functions and types")
    func topLevelClause() {
        let record = record("debugLog(_:)", """
        #if DEBUG
        var verboseLogging = true
        final class DebugLogger {
            static let shared = DebugLogger()
            func write(_ text: String) {}
        }
        func trace(_ text: String) {}
        func debugLog(_ text: String) {
            trace(text)
            if verboseLogging {
                DebugLogger.shared.write(text)
            }
        }
        #endif
        """)

        #expect(Modules.headline(record) == ["?.write(_:)", "free.trace(_:)"])
        #expect(record?.commonCoupling?.mutableGlobals == ["verboseLogging"])
        #expect(record?.commonCoupling?.singletons == ["DebugLogger.shared"])
        #expect(record?.typeReferences.contains { $0.spelling == "DebugLogger" && $0.bucket == .module } == true)
    }
    @Test("guard case and tuple bindings in a body #if clause are locals")
    func clauseBindingPatterns() {
        let record = record("check(_:)", """
        var value = 0
        var first = 0
        func check(_ maybe: Int?) {
            #if DEBUG
            guard case let .some(value) = maybe, let (first, _) = Optional((1, 2)) else { return }
            print(value, first)
            #endif
        }
        """)

        #expect(record?.commonCoupling?.globals.isEmpty == true)
    }
    @Test("a backticked nested type resolves from expressions and type positions alike")
    func backtickedType() {
        let record = record("isWord()", """
        struct Token {
            enum `Type` { case word, number }
            let kind: `Type`
            func isWord() -> Bool { kind == `Type`.word }
        }
        """)

        let type = record?.typeReferences.first { $0.spelling == "Type" }
        #expect(type?.bucket == .module)
        #expect(type?.target?.path == ["Token", "Type"])
    }

    private func record(_ name: String, _ source: String) -> FunctionRecord? {
        Modules.record(name, in: Modules.analysis("Lib", [("A.swift", source)]))
    }
}
