//
//  ReviewRoundFourCallTests.swift
//  SwiftCodeMetricsTests
//
//  Regression tests from the fourth review round: names shared with the
//  module, generic-parameter calls and `#if` variants of statics.
//

import SwiftCodeMetrics
import Testing

@Suite("v0.2 review regressions, round 4: calls and statics")
struct ReviewRoundFourCallTests {
    @Test("ThisModule.global is a global, not an external type")
    func qualifiedGlobal() {
        let record = record("qualifiedTimeout()", """
        struct Config { var timeout = 30 }
        let DefaultConfig = Config()
        func qualifiedTimeout() -> Int { Lib.DefaultConfig.timeout }
        """)

        #expect(record?.typeReferences.map(\.spelling) == ["Int"])
        #expect(record?.commonCoupling?.globals == ["DefaultConfig"])
    }
    @Test("a module type named like the module shadows the module in dotted names")
    func typeNamedLikeModule() {
        let record = record("run()", """
        enum Lib {
            static let version = "1.0"
            static func analyze() -> Int { 0 }
            struct Options { init() {} }
        }
        func run() -> Int {
            _ = Lib.Options()
            _ = Lib.Options.init()
            _ = Lib.version
            return Lib.analyze()
        }
        """)

        #expect(Modules.headline(record) == ["Lib.Options.init()", "Lib.analyze()"])
        #expect(record?.fanOut?.calls.first { $0.key == "Lib.Options.init()" }?.siteCount == 2)
        #expect(record?.commonCoupling?.statics == ["Lib.version"])
    }
    @Test("ThisModule.X() names the top-level X, as ThisModule.X.init() does")
    func thisModuleTopLevel() {
        let record = record("make()", """
        struct Item { init() {} }
        struct Outer {
            struct Item { init() {} }
            func make() {
                _ = Lib.Item()
                _ = Lib.Item.init()
                _ = Lib::Item()
            }
        }
        """)

        #expect(Modules.headline(record) == ["Item.init()"])
        #expect(record?.fanOut?.calls.first?.siteCount == 3)
    }
    @Test("T() and T.init() on a generic parameter share a T key (Spec §7.5)")
    func genericParameterCalls() {
        let analysis = Modules.analysis("Lib", [
            ("A.swift", """
            protocol Makeable {
                init()
                static func make() -> Self
            }
            func build<T: Makeable>(_ type: T.Type) -> [T] { [T(), T.init(), T.make()] }
            struct Box<Element: Makeable> {
                func fresh() -> [Element] { [Element(), Element.init()] }
            }
            """)
        ])

        let build = Modules.record("build(_:)", in: analysis)
        #expect(Modules.headline(build) == ["T.init()", "T.make()"])
        #expect(Modules.keys(build, .type) == ["T.init()", "T.make()"])
        #expect(Modules.headline(Modules.record("fresh()", in: analysis)) == ["Element.init()"])
    }

    private func record(_ name: String, _ source: String) -> FunctionRecord? {
        Modules.record(name, in: Modules.analysis("Lib", [("A.swift", source)]))
    }
}
