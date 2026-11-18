//
//  TypeInvariantTests.swift
//  SwiftCodeMetricsTests
//
//  Spec §16 v0.3 invariants: the ce split sums to ce, the NOM partition
//  sums to nom, LCOM4 never exceeds |A|, and each null reason of §9.3 is
//  hit first by a test of its own.
//

import Foundation
import SwiftCodeMetrics
import Testing

@Suite("Type invariants (Spec §16 v0.3)")
struct TypeInvariantTests {
    private static let home = FileManager.default.homeDirectoryForCurrentUser.path
    private static let corpora = [
        ("HeapModule", home + "/GitHub_projects/swift-collections/Sources/HeapModule"),
        ("NIOCore", home + "/GitHub_projects/swift-nio/Sources/NIOCore"),
        ("SyncUps", home + "/GitHub_projects/swift-composable-architecture/Examples/SyncUps/SyncUps"),
        ("App", home + "/xcode_projects/SwiftProjectLint/Sources/App")
    ].filter { FileManager.default.fileExists(atPath: $0.1) }

    @Test("ce = ceProtocol + ceView + ceNamespace + ceConcrete; instance + static = nom; lcom4 ≤ |A|")
    func invariants() {
        let analyses = [
            Modules.analysis("Shop", TypeExamples.shop),
            Modules.analysis("App", TypeExamples.session + TypeExamples.formatter),
            Modules.analysis("App", TypeExamples.app),
            Modules.analysis("App", TypeExamples.shapes)
        ] + Self.corpora.map { Modules.analysis($0.0, Resolutions.files(under: $0.1)) }
        var checked = 0
        for type in analyses.flatMap(\.types) {
            let coupling = type.coupling
            #expect(
                coupling.ceTotal == coupling.ceProtocol + coupling.ceView + coupling.ceNamespace + coupling.ceConcrete,
                "\(type.key)"
            )
            #expect(type.sizes.instanceMembers + type.sizes.staticMembers == type.sizes.nom, "\(type.key)")
            if let lcom4 = type.cohesion.lcom4 {
                #expect(lcom4 <= type.cohesion.attributeCount, "\(type.key)")
                #expect(type.cohesion.nullReason == nil, "\(type.key)")
            } else {
                #expect(type.cohesion.nullReason != nil, "\(type.key)")
            }
            checked += 1
        }
        #expect(checked > 0)
    }

    @Test("notApplicableKind wins for an enum, though it has no stored properties either")
    func notApplicableKind() {
        let type = type("Mode", """
        enum Mode {
            case on, off
            func flip() -> Mode { self == .on ? .off : .on }
            var label: String { "\\(self)" }
        }
        """)

        #expect(type?.cohesion.nullReason == .notApplicableKind)
    }

    @Test("noStoredProperties wins over fewerThanTwoMembers")
    func noStoredProperties() {
        let type = type("Loader", """
        struct Loader {
            func load() -> Int { 1 }
        }
        """)

        #expect(type?.cohesion.attributeCount == 0)
        #expect(type?.cohesion.nodeCount == 1)
        #expect(type?.cohesion.nullReason == .noStoredProperties)
    }

    @Test("fewerThanTwoMembers wins over noStateUse")
    func fewerThanTwoMembers() {
        let type = type("Counter", """
        struct Counter {
            var count = 0
            init() {}
            func constant() -> Int { 1 }
        }
        """)

        #expect(type?.cohesion.nodeCount == 1)
        #expect(type?.cohesion.nullReason == .fewerThanTwoMembers)
    }

    @Test("noStateUse when every component is attribute-free")
    func noStateUse() {
        let type = type("Clock", """
        struct Clock {
            let zone: String
            func now() -> Int { 1 }
            func later() -> Int { now() + 1 }
        }
        """)

        #expect(type?.cohesion.nullReason == .noStateUse)
        #expect(type?.cohesion.isolatedMembers.count == 2)
    }

    private func type(_ name: String, _ source: String) -> TypeResult? {
        Modules.type(name, in: Modules.analysis("Lib", [("A.swift", source)]))
    }
}
