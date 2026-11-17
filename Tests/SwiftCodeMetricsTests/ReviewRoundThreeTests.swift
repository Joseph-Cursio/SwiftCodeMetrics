//
//  ReviewRoundThreeTests.swift
//  SwiftCodeMetricsTests
//
//  Regression tests from the third v0.2 review round: `#if` in bodies,
//  macro contexts, free-function visibility and resolution order.
//

import SwiftCodeMetrics
import Testing

@Suite("v0.2 review regressions, round 3")
struct ReviewRoundThreeTests {
    @Test("locals declared inside a #if clause are locals")
    func localsInIfConfigClause() {
        let record = record("load()", """
        var retryCount = 0
        struct Loader {
            func load() {
                #if DEBUG
                let retryCount = 3
                let trace = { (message: String) in _ = message }
                trace("load")
                print(retryCount)
                #endif
            }
        }
        """)

        #expect(record?.commonCoupling?.globals.isEmpty == true)
        #expect(record?.fanOut?.fanOut == 0)
    }

    @Test("#if conditions in a body are not calls (Spec §2.6)")
    func ifConfigConditions() {
        let record = record("configure()", """
        func setup() {}
        func configure() {
            #if os(iOS)
            setup()
            #elseif canImport(AppKit)
            setup()
            #endif
        }
        """)

        #expect(Modules.headline(record) == ["free.setup()"])
    }

    @Test("types in a top-level #Preview are local to it and resolve their own members")
    func previewLocalTypes() {
        let analysis = Modules.analysis("App", [
            ("HostPreview.swift", """
            #Preview {
                struct Host {
                    var count = 0
                    static let seed = 3
                    static func make() -> Int { seed }
                    func total() -> Int { double() }
                    func double() -> Int { count * 2 }
                }
                return Host().total()
            }
            """)
        ])

        #expect(Modules.headline(Modules.record("total()", in: analysis)) == ["self.double()"])
        #expect(Modules.record("make()", in: analysis)?.commonCoupling?.statics == ["Host.seed"])
    }

    @Test("private free functions are visible only in their file; backticked names match")
    func freeFunctionVisibility() {
        let analysis = Modules.analysis("Lib", [
            ("A.swift", """
            private func log(_ message: String) {}
            private func print(_ items: Any...) {}
            func `default`() -> Int { 0 }
            """),
            ("B.swift", """
            import Foundation
            struct Curve {
                func value(_ x: Double) -> Double { print("value"); return log(x) }
                func fallback() -> Int { `default`() }
            }
            """)
        ])

        #expect(Modules.headline(Modules.record("value(_:)", in: analysis)) == ["implicit.log(_:)"])
        #expect(Modules.headline(Modules.record("fallback()", in: analysis)) == ["free.default()"])
    }

    @Test("a module-qualified free function adds no type reference")
    func qualifiedFreeFunctionReference() {
        let record = record("report(_:)", """
        import Foundation
        func report(_ message: String) {
            Foundation.NSLog(message)
            Foundation::NSLog(message)
        }
        """)

        #expect(record?.typeReferences.map(\.spelling) == ["String"])
    }

    @Test("extension groups: Self is the platform type; nested types see the group")
    func extensionGroupChains() {
        let analysis = Modules.analysis("Lib", [
            ("A.swift", """
            extension String {
                func twice() -> Self { self + self }
                enum Grade { case short, long }
                typealias Tally = Int
                typealias Transform = (Character) -> Character
                enum Limits {
                    static func classify(_ count: Tally) -> Grade { count > 40 ? .long : .short }
                }
            }
            func apply(_ transform: String.Transform) {}
            func applyLater(_ transform: String.Transform?) {}
            """)
        ])
        let classify = Modules.record("classify(_:)", in: analysis)

        #expect(Modules.record("twice()", in: analysis)?.typeReferences.map(\.bucket) == [.platform])
        #expect(classify?.typeReferences.map(\.bucket) == [.platform, .module])
        #expect(classify?.typeReferences.last?.target?.path == ["String", "Grade"])
        #expect(Modules.record("apply(_:)", in: analysis)?.parameters?.closureParameterCount == 1)
        #expect(Modules.record("applyLater(_:)", in: analysis)?.parameters?.escapingClosureParameterCount == 1)
    }

    @Test("a typealias to `any P` is a reference to P")
    func anyAlias() {
        let record = record("total(_:)", """
        protocol Shape { func area() -> Double }
        typealias AnyShape = any Shape
        func total(_ shape: AnyShape) -> Double { shape.area() }
        """)

        #expect(record?.typeReferences.first?.target == TypeKey(module: "Lib", path: ["Shape"]))
    }

    @Test("resolution order: function-local types, then the nesting chain, then written paths")
    func resolutionOrder() {
        let analysis = Modules.analysis("Lib", [
            ("A.swift", """
            struct Outer {
                struct Item {}
                func build() {
                    struct Item { var id = 0 }
                    func make(_ item: Item) -> Int { item.id }
                }
            }
            extension Result { enum Kind { case cached } }
            struct Parser {
                enum Result { enum Kind { case parsed } }
                func kind() -> Result.Kind { .parsed }
            }
            """)
        ])

        #expect(Modules.record("make(_:)", in: analysis)?.typeReferences.first?.target?.localTo != nil)
        let kind = Modules.record("kind()", in: analysis)
        #expect(kind?.typeReferences.first?.target?.path == ["Parser", "Result", "Kind"])
    }

    @Test("Self.X(...) and Self.X.init(...) share a key when X is not found")
    func selfUnresolvedKeys() {
        let record = record("reset()", """
        @Reducer
        struct Feature {
            func reset() -> Int {
                _ = Self.State()
                _ = Self.State.init()
                _ = Self.State.make()
                return 0
            }
        }
        """)

        #expect(Modules.headline(record) == ["Feature.State.init()", "Feature.State.make()"])
    }

    @Test("a Lib:: selector cannot be shadowed by a type named Lib")
    func selectorShadow() {
        let record = record("build()", """
        enum Lib { static let version = 1 }
        struct Store { static func make() -> Store { Store() } }
        func build() -> Store { Lib::Store.make() }
        """)

        #expect(Modules.headline(record) == ["Store.make()"])
    }

    @Test("qualified calls of a module global closure count as global references")
    func qualifiedGlobalCalls() {
        let analysis = Modules.analysis("Lib", [
            ("A.swift", """
            var onEvent: () -> Void = {}
            func fireQualified() { Lib.onEvent() }
            func fireSelector() { Lib::onEvent() }
            """)
        ])

        for name in ["fireQualified()", "fireSelector()"] {
            #expect(Modules.record(name, in: analysis)?.commonCoupling?.mutableGlobals == ["onEvent"], "\(name)")
        }
    }

    @Test("closure aliases: a local nested type shadows an alias")
    func localShadowedAlias() {
        let record = record("run(_:)", """
        typealias Handler = () -> Void
        func outer() {
            struct Local {
                struct Handler { var name: String }
                func run(_ handler: Handler) {}
            }
        }
        """)

        #expect(record?.parameters?.closureParameterCount == 0)
    }

    @Test("an extension of a missing nested type of a module type forms no group")
    func unresolvedExtension() {
        let record = record("reset()", """
        struct Feature { }
        extension Feature.State {
            static let initial = 0
            static func reset() -> Int { initial }
        }
        """)

        #expect(record?.commonCoupling?.statics.isEmpty == true)
    }

    @Test("singletons initialised through the module name; closure calls despite other labels")
    func staticEdges() {
        let analysis = Modules.analysis("Lib", [
            ("A.swift", """
            final class Manager { static let shared = Lib.Manager() }
            func use() { _ = Manager.shared }
            enum Hooks {
                static var onSave: () -> Void = {}
                static func onSave(_ code: Int) {}
                static func save() { onSave() }
            }
            """)
        ])

        #expect(Modules.record("use()", in: analysis)?.commonCoupling?.singletons == ["Manager.shared"])
        #expect(Modules.record("save()", in: analysis)?.commonCoupling?.statics == ["Hooks.onSave"])
    }

    private func record(_ name: String, _ source: String) -> FunctionRecord? {
        Modules.record(name, in: Modules.analysis("Lib", [("A.swift", source)]))
    }
}
