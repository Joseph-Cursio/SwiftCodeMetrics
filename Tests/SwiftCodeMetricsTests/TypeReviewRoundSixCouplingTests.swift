//
//  TypeReviewRoundSixCouplingTests.swift
//  SwiftCodeMetricsTests
//
//  Regression tests from the sixth v0.3 review round: inherited methods
//  and overrides in cohesion, qualified candidates, module-named types,
//  entry kinds and typealias imports (Spec §7.3, §9.3, §9.4).
//

import SwiftCodeMetrics
import Testing

@Suite("v0.3 review regressions, round 6: cohesion and coupling")
struct TypeReviewRoundSixCouplingTests {
    @Test("inherited methods and overrides are references, not touches of inherited storage")
    func inheritedReferences() throws {
        let analysis = Modules.analysis("Lib", [
            ("A.swift", """
            class Store {
                var value = 0
                func value(for key: String) -> Int { key.count }
            }
            final class Cache: Store {
                var label = ""
                func first() -> Int { value(for: "a") }
                func second() -> Int { self.value(for: "b") }
                func third() -> String { label }
            }
            class Base {
                var value = 0
            }
            class Fixed: Base {
                override var value: Int {
                    get { 42 }
                    set { }
                }
            }
            final class Leaf: Fixed {
                var label = ""
                func first() -> Int { value * 2 }
                func third() -> String { label }
            }
            class Updating {
                var a = 0
                func update(by step: Int) { a += step }
            }
            final class Updater: Updating {
                var b = 0
                var c = 0
                func update(to value: Int) { b = value }
                func handler() -> (Int) -> Void {
                    c += 1
                    return self.update(by:)
                }
            }
            """)
        ])
        let cache = try #require(Modules.type("Cache", in: analysis))
        let leaf = try #require(Modules.type("Leaf", in: analysis))
        let updater = try #require(Modules.type("Updater", in: analysis))

        #expect(cache.cohesion.lcom4 == 1)
        #expect(cache.cohesion.inheritedMemberRefs == ["value"])
        #expect(leaf.cohesion.lcom4 == 1)
        #expect(leaf.cohesion.inheritedMemberRefs == ["value"])
        #expect(updater.cohesion.lcom4 == 2)
        #expect(updater.cohesion.inheritedMemberRefs == ["update"])
    }

    @Test("qualified candidates reach group-nested types; a type named like the module is a type")
    func qualifiedCandidates() {
        let app = Modules.analysis("App", [
            ("A.swift", """
            extension String {
                enum Limits { static func clamp(_ value: Int) -> Int { value > 80 ? 80 : value } }
            }
            struct Validator { func check(_ value: Int) -> Int { Swift.String.Limits.clamp(value) } }
            struct SelectorValidator { func check(_ value: Int) -> Int { Swift::String.Limits.clamp(value) } }
            """)
        ])
        let shop = Modules.analysis("Shop", [
            ("Shop.swift", """
            enum Shop {
                struct Item { var price = 0 }
                static func make() -> Item { Item() }
            }
            struct Cart {
                func first() -> Int { Shop.Item().price }
                func second() -> Int { Shop.make().price }
            }
            """)
        ])

        #expect(Modules.type("Validator", in: app)?.coupling.ceTotal == 1)
        #expect(Modules.type("SelectorValidator", in: app)?.coupling.ceTotal == 1)
        #expect(Modules.type("Cart", in: shop)?.coupling.ceTotal == 2)
    }

    @Test("entry kinds for composition arguments and protocol aliases; aliases resolve with their own imports")
    func kindsAndAliasImports() throws {
        let analysis = Modules.analysis("App", [
            ("A.swift", """
            import Charts
            protocol HasAPI {}
            protocol HasStore {}
            typealias Dependencies = HasAPI & HasStore
            class BaseViewModel<Deps> {}
            class ViewModel: BaseViewModel<any Dependencies> {}
            typealias Key = Hashable
            final class Token: Key {
                let raw = 0
                static func == (lhs: Token, rhs: Token) -> Bool { lhs.raw == rhs.raw }
                func hash(into hasher: inout Hasher) { hasher.combine(raw) }
            }
            typealias Plot = Charts.Chart
            extension Dashboard { func render() -> Charts.Chart? { nil } }
            """),
            ("B.swift", "struct Dashboard { let plot: Plot }")
        ])
        let protocolEdges = analysis.typeEdges.filter { edge in
            edge.source.path == ["ViewModel"] && edge.target.path != ["BaseViewModel"]
        }
        let token = try #require(Modules.type("Token", in: analysis))

        #expect(protocolEdges.count == 2)
        #expect(protocolEdges.allSatisfy { $0.kinds == [.inheritance] })
        #expect(token.declarationTypeReferences.first { $0.spelling == "Key" }?.edgeKind == .conformance)
        #expect(Modules.type("Dashboard", in: analysis)?.coupling.externalNameCount == 1)
    }
}
