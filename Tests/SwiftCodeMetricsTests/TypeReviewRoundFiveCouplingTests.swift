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
