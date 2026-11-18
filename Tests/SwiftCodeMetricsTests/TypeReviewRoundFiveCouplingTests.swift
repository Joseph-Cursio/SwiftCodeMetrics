//
//  TypeReviewRoundFiveCouplingTests.swift
//  SwiftCodeMetricsTests
//
//  Regression tests from the fifth v0.3 review round: cohesion uses that
//  reach overrides and inherited members, edge kinds and names, and module
//  selectors (Spec §7.3, §9.3, §9.4).
//

import SwiftCodeMetrics
import Testing

@Suite("v0.3 review regressions, round 5: cohesion, coupling and selectors")
struct TypeReviewRoundFiveCouplingTests {
    @Test("an own computed override is a node; inherited methods and $ names reach the superclass")
    func cohesionOverrides() throws {
        let analysis = Modules.analysis("Lib", [
            ("A.swift", """
            import os
            class Base {
                var value = 0
                func total(of items: [Int]) -> Int { items.reduce(0, +) }
            }
            final class Sub: Base {
                var a = 0
                var b = 0
                override var value: Int {
                    get { a }
                    set { a = newValue }
                }
                func readValue() -> Int { value * 2 }
                func readB() -> Int { b }
            }
            final class Counter: Base {
                var total = 0
                var other = 0
                func combined() -> Int { total(of: [other]) }
                func readTotal() -> Int { total }
                func readOther() -> Int { other }
                func log() { _ = os.Logger(subsystem: "x", category: "y") }
            }
            """)
        ])
        let sub = try #require(Modules.type("Sub", in: analysis))
        let counter = try #require(Modules.type("Counter", in: analysis))

        #expect(sub.cohesion.lcom4 == 2)
        #expect(counter.cohesion.lcom4 == 2)
        #expect(counter.cohesion.inheritedMemberRefs == ["total"])
        #expect(counter.cohesion.unresolvedMemberRefs.isEmpty)
    }

    @Test("a projected name that reaches an inherited property is inherited, the option off")
    func projectedInheritedNames() throws {
        var options = MetricsOptions()
        options.cohesion.inheritsModuleSuperclassAttributes = false
        let input = Modules.input("Lib", [
            ("A.swift", """
            @propertyWrapper
            struct Tracked<Value> {
                var wrappedValue: Value
                var projectedValue: Int { 0 }
            }
            class Base {
                @Tracked var value = 0
            }
            final class Sub: Base {
                var a = 0
                var b = 0
                func value(for key: String) -> Int { a }
                func observe() -> Int { $value + b }
            }
            """)
        ])
        let analysis = SwiftCodeMetrics.analyzeModule(input, options: options)
        let sub = try #require(Modules.type("Sub", in: analysis))

        #expect(sub.cohesion.lcom4 == 2)
        #expect(sub.cohesion.inheritedMemberRefs == ["value"])
    }

    @Test("edges: nested heads are body; group aliases, alias candidates, selector views, inline arrays")
    func edgesAndNames() throws {
        let analysis = Modules.analysis("App", [
            ("A.swift", """
            import SwiftUI
            struct Cell {}
            struct User {}
            struct Report {
                func render() -> String {
                    func format(_ cell: Cell) -> String { "" }
                    return ""
                }
            }
            extension String { typealias Owner = User }
            struct Card { let owner: String.Owner }
            protocol HasAPI {}
            protocol HasStore {}
            typealias Deps = HasAPI & HasStore
            struct Registry { func register() -> Any.Type { Deps.self } }
            struct Row: SwiftUI::View { var body: some SwiftUI::View { Text("row") } }
            struct Screen { let row: Row }
            struct Buffer { var cells: [4 of Cell] }
            """)
        ])
        let report = analysis.typeEdges.first { $0.source.path == ["Report"] }
        let card = try #require(Modules.type("Card", in: analysis))

        #expect(report?.kinds == [.body])
        #expect(card.coupling.ceTotal == 1)
        #expect(card.coupling.platformNameCount == 0)
        #expect(Modules.type("Registry", in: analysis)?.coupling.ceProtocol == 2)
        #expect(Modules.type("Screen", in: analysis)?.coupling.ceView == 1)
        #expect(Modules.type("Buffer", in: analysis)?.coupling.platformNameCount == 1)
    }

    @Test("another module's selector is never shadowed by a module type named like that module")
    func foreignSelectors() throws {
        let bridge = ("Bridge.swift", """
        import Core
        extension Core::Item { func describe() -> String { "external" } }
        """)
        let nested = Modules.analysis("App", [
            ("Namespace.swift", """
            import Core
            enum Core {
                struct Item {
                    var name = ""
                    func label() -> String { name }
                }
            }
            """),
            bridge
        ])
        let flat = Modules.analysis("App", [("Namespace.swift", "struct Core {}"), bridge])
        let item = try #require(Modules.type("Core.Item", in: nested))

        #expect(item.sizes.nom == 1)
        #expect(item.extensions.isEmpty)
        #expect(nested.types.contains { $0.key.path == ["Item"] && $0.kind == .extensionGroup })
        #expect(flat.unresolvedExtensions.isEmpty)
        #expect(flat.types.contains { $0.key.path == ["Item"] && $0.kind == .extensionGroup })
    }

    @Test("selector spellings reach a group kept on its written path, inside and out")
    func selectorGroups() throws {
        let analysis = Modules.analysis("App", [
            ("Result.swift", """
            struct Result { static var cache: [Int] = [] }
            var cache: [Int] = []
            struct ViaSelector { let box: Swift::Result.Box }
            struct ViaDot { let box: Swift.Result.Box }
            """),
            ("Ext.swift", """
            extension Swift::Result {
                func size() -> Int { cache.count }
                struct Box {
                    var count = 0
                    var label = ""
                    mutating func bump() { count += 1 }
                    func describe() -> String { label + String(count) }
                }
            }
            """)
        ])
        let box = try #require(Modules.type("Swift.Result.Box", in: analysis))
        let via = try #require(Modules.type("ViaSelector", in: analysis))

        #expect(via.coupling.ceTotal == 1)
        #expect(via.coupling.platformNameCount == 0)
        #expect(box.coupling.caWithinModule == 2)
        #expect(box.cohesion.lcom4 == 1)
        #expect(box.cohesion.unresolvedMemberRefs.isEmpty)
        #expect(Modules.record("size()", in: analysis)?.commonCoupling?.globals == ["cache"])
    }
}
