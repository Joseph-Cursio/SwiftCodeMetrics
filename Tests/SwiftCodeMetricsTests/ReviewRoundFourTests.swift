//
//  ReviewRoundFourTests.swift
//  SwiftCodeMetricsTests
//
//  Regression tests from the fourth review round: `#if` clauses at file
//  scope, binding patterns, typealias variants, backticked names and
//  top-level code.
//

import SwiftCodeMetrics
import SwiftParser
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
    @Test("a typealias whose #if variants reach different types is ambiguous (Spec §7.3)")
    func clauseAliasVariants() {
        let analysis = Modules.analysis("Lib", [
            ("A.swift", """
            struct LiveClient { }
            struct MockClient { }
            #if DEBUG
            typealias Client = MockClient
            typealias Same = LiveClient
            #else
            typealias Client = LiveClient
            typealias Same = LiveClient
            #endif
            struct Holder {
                #if DEBUG
                typealias Handler = () -> Void
                #else
                typealias Handler = Int
                #endif
            }
            func load(using client: Client) { }
            func same(_ value: Same) { }
            func held(_ value: Holder.Handler) { }
            """)
        ])

        #expect(Modules.record("load(using:)", in: analysis)?.typeReferences.map(\.resolution) == [.ambiguous])
        #expect(Modules.record("same(_:)", in: analysis)?.typeReferences.first?.target?.path == ["LiveClient"])
        #expect(Modules.record("held(_:)", in: analysis)?.parameters?.closureParameterCount == 0)
    }
    @Test("Self.State names an associated type; Self in a group of an alias is the target")
    func selfMembers() {
        let analysis = Modules.analysis("Lib", [
            ("A.swift", """
            protocol Store {
                associatedtype State
                var state: State { get }
            }
            extension Store {
                func snapshot() -> Self.State { state }
            }
            typealias Celsius = Double
            extension Celsius {
                static func fromKelvin(_ value: Double) -> Self { value - 273.15 }
            }
            extension String {
                enum Grade { case short, long }
                func grade() -> Self.Grade { .short }
            }
            """)
        ])

        #expect(Modules.record("snapshot()", in: analysis)?.typeReferences.isEmpty == true)
        #expect(Modules.record("fromKelvin(_:)", in: analysis)?.typeReferences.map(\.bucket) == [.platform, .platform])
        let grade = Modules.record("grade()", in: analysis)?.typeReferences.first
        #expect(grade?.bucket == .module)
        #expect(grade?.target?.path == ["String", "Grade"])
    }
    @Test("a placeholder type adds no reference")
    func placeholderType() {
        let record = record("tally()", """
        func tally() -> [String: Int] {
            let counts: [String: _] = ["a": 1]
            return counts
        }
        """)

        #expect(record?.typeReferences.contains { $0.spelling == "_" } == false)
    }
    @Test("closure aliases: a function-local type shadows the enclosing type's alias")
    func localTypeShadowsMemberAlias() {
        let record = record("perform(_:)", """
        struct Screen {
            typealias Action = () -> Void
            func run() {
                struct Action { var title = "" }
                func perform(_ action: Action) { _ = action.title }
            }
        }
        """)

        #expect(record?.parameters?.closureParameterCount == 0)
    }
    @Test("recursion through backticked names and labels (Spec §3.4)")
    func backtickedRecursion() {
        let functions = complexity("""
        enum Theme {
            case light, dark
            static func `default`(depth: Int) -> Theme {
                depth > 0 ? Self.default(depth: depth - 1) : .light
            }
        }
        struct Walker {
            func countdown(`in` count: Int) -> Int {
                count == 0 ? 0 : countdown(in: count - 1)
            }
        }
        """)

        #expect(functions.first { $0.name == "`default`(depth:)" }?.complexity.cognitive == 2)
        #expect(functions.first { $0.name.hasPrefix("countdown") }?.complexity.cognitive == 2)
    }

    private func complexity(_ source: String) -> [FunctionRecord] {
        let input = SourceFileInput(path: "main.swift", tree: Parser.parse(source: source))
        return SwiftCodeMetrics.functionMetrics(of: input, module: "Lib").functions
    }

    private func record(_ name: String, _ source: String) -> FunctionRecord? {
        Modules.record(name, in: Modules.analysis("Lib", [("A.swift", source)]))
    }
}
