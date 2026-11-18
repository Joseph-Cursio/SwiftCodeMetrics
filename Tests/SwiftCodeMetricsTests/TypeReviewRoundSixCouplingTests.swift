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
}
