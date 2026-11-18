//
//  TypeReviewRoundThreeCouplingTests.swift
//  SwiftCodeMetricsTests
//
//  Regression tests from the third v0.3 review round: compositions, edge
//  kinds, name counts and wrapper names (Spec §9.3–9.5).
//

import SwiftCodeMetrics
import Testing

@Suite("v0.3 review regressions, round 3: compositions and coupling")
struct TypeReviewRoundThreeCouplingTests {
    /// The kinds of the edge from `source` to `target`, both dotted paths.
    private static func kinds(_ source: String, _ target: String, in analysis: ModuleAnalysis) -> Set<EdgeKind> {
        let edge = analysis.typeEdges.first { edge in
            edge.source.path.joined(separator: ".") == source && edge.target.path.joined(separator: ".") == target
        }
        return edge?.kinds ?? []
    }

    @Test("a protocol's class constraint is inheritance, directly or through a composition alias")
    func classConstrainedProtocols() {
        let analysis = Modules.analysis("Lib", [
            ("A.swift", """
            class BaseView {}
            protocol Styled {}
            protocol Themed: BaseView {}
            typealias StyledBase = BaseView & Styled
            protocol Fancy: StyledBase {}
            """)
        ])

        #expect(Self.kinds("Themed", "BaseView", in: analysis) == [.inheritance])
        #expect(Self.kinds("Fancy", "BaseView", in: analysis) == [.inheritance])
        #expect(Self.kinds("Fancy", "Styled", in: analysis) == [.refinement])
        #expect(Modules.type("BaseView", in: analysis)?.coupling.caWithinModule == 2)
    }

    @Test("an external protocol's arguments in a later class entry or an extension are conformance")
    func externalProtocolArguments() {
        let analysis = Modules.analysis("Lib", [
            ("A.swift", """
            import Storage
            struct Item {}
            class Base {}
            final class Cache: Base, Persistable<Item> {}
            final class Store {}
            extension Store: Persistable<Item> {}
            final class Root: Persistable<Item> {}
            """)
        ])

        #expect(Self.kinds("Cache", "Base", in: analysis) == [.inheritance])
        #expect(Self.kinds("Cache", "Item", in: analysis) == [.conformance])
        #expect(Self.kinds("Store", "Item", in: analysis) == [.conformance])
        #expect(Self.kinds("Root", "Item", in: analysis) == [.inheritance])
    }

    @Test("compositions: diamonds expand fully, #if variants conflict, and other positions name the members")
    func compositions() throws {
        let analysis = Modules.analysis("Lib", [
            ("A.swift", """
            protocol Loading {}
            protocol Saving {}
            protocol Caching {}
            protocol Logging {}
            typealias Persisting = Loading & Saving
            typealias ReadServices = Persisting & Caching
            typealias WriteServices = Persisting & Logging
            typealias AppServices = ReadServices & WriteServices
            struct Client: AppServices {}
            #if os(iOS)
            typealias Services = Loading & Saving
            #else
            typealias Services = Loading & Caching
            #endif
            struct Worker: Services {}
            struct Feature {
                let deps: Persisting
                init(deps: Persisting) { self.deps = deps }
            }
            """)
        ])
        let client = try #require(Modules.type("Client", in: analysis))
        let feature = try #require(Modules.type("Feature", in: analysis))
        let initRecord = try #require(Modules.record("init(deps:)", in: analysis))

        #expect(client.conformances.map(\.name) == ["Loading", "Saving", "Caching", "Logging"])
        #expect(client.conformances.allSatisfy { $0.target != nil })
        #expect(Modules.targets(of: Modules.type("Worker", in: analysis), in: analysis).isEmpty)
        #expect(Modules.type("Saving", in: analysis)?.protocolFacts?.conformerCount == 1)
        #expect(Modules.type("Caching", in: analysis)?.protocolFacts?.conformerCount == 1)
        #expect(feature.coupling.ceProtocol == 2)
        #expect(Self.kinds("Feature", "Loading", in: analysis) == [.signature, .storedProperty])
        #expect(initRecord.typeReferences.map(\.spelling).sorted() == ["Loading", "Saving"])
    }

    @Test("built-in attributes name no type; Swift.Int and Int are one platform name")
    func nameCounts() throws {
        let analysis = Modules.analysis("Lib", [
            ("A.swift", """
            import AppKit
            final class Panel: NSViewController {
                @IBOutlet weak var label: NSTextField!
                @IBInspectable var radius: Double = 0
            }
            struct Span {
                let start: Int
                let end: Swift.Int
            }
            """)
        ])
        let panel = try #require(Modules.type("Panel", in: analysis))

        #expect(panel.coupling.externalNameCount == 2)
        #expect(panel.declarationTypeReferences.allSatisfy { $0.edgeKind != .wrapper })
        #expect(Modules.type("Span", in: analysis)?.coupling.platformNameCount == 1)
    }

    @Test("a bare _name that resolves to a global is not a wrapper name")
    func globalUnderscoreName() {
        let analysis = Modules.analysis("Lib", [
            ("Globals.swift", "let _limit = 10\n"),
            ("Gauge.swift", """
            struct Gauge {
                var limit = 0
                var level = 0
                func capped() -> Int { min(level, _limit) }
                func raise() -> Int { limit + 1 }
                func fill() -> Int { level }
            }
            """)
        ])

        #expect(Modules.type("Gauge", in: analysis)?.cohesion.lcom4 == 2)
    }
}
