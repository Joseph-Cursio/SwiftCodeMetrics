//
//  TypeReviewRoundTwoCouplingTests.swift
//  SwiftCodeMetricsTests
//
//  Regression tests from the second v0.3 review round: cohesion accesses
//  and edges, requirement signatures, wrappers, compositions and
//  re-exports (Spec §9.3–9.5, §10).
//

import SwiftCodeMetrics
import Testing

@Suite("v0.3 review regressions, round 2: cohesion and coupling")
struct TypeReviewRoundTwoCouplingTests {
    @Test("T.self and \\.self are not whole-self uses; an inherited _name is not a wrapper name")
    func selfUses() {
        let analysis = Modules.analysis("Lib", [
            ("A.swift", """
            struct Pair {
                var left = 0
                var right = 0
                func first() -> Int { left }
                func second() -> Int { _ = Int.self; _ = [1].map(\\.self); return right }
            }
            class Base { var _name = "" }
            final class Named: Base {
                var size = 0
                func a() -> String { _name }
                func b() -> Int { size }
            }
            """)
        ])

        #expect(Modules.type("Pair", in: analysis)?.cohesion.lcom4 == 2)
        #expect(Modules.type("Named", in: analysis)?.cohesion.unresolvedMemberRefs.isEmpty == true)
        #expect(Modules.type("Named", in: analysis)?.cohesion.lcom4 == 2)
    }

    @Test("calls and reads pick the member they name: methods over closures, labels, properties")
    func memberSelection() {
        let analysis = Modules.analysis("Lib", [
            ("A.swift", """
            struct Runner {
                var task: (Int) -> Int = { $0 }
                var log: [String] = []
                func task(named name: String) -> Int { log.count }
                func run() -> Int { task(named: "x") }
            }
            struct Mapper {
                var a = 0
                var b = 0
                func f(x: Int) -> Int { a + x }
                func f(y: Int) -> Int { b + y }
                func g() -> (Int) -> Int { self.f(y:) }
            }
            struct Counter {
                var items: [Int] = []
                var limit = 0
                var count: Int { items.count }
                func count(of value: Int) -> Int { limit }
                func report() -> Int { count }
            }
            """)
        ])

        #expect(Modules.type("Runner", in: analysis)?.cohesion.unusedAttributes == ["task"])
        #expect(Modules.type("Mapper", in: analysis)?.cohesion.lcom4 == 2)
        #expect(Modules.type("Counter", in: analysis)?.cohesion.lcom4 == 2)
    }

    @Test("requirement signatures: subscript constraints and accessor throws; parameterized protocol entries refine")
    func requirementSignatures() throws {
        let analysis = Modules.analysis("Lib", [
            ("A.swift", """
            protocol Key {}
            enum Failure: Error {}
            struct Item {}
            protocol Table {
                subscript<K>(key: K) -> Int where K: Key { get }
                var current: Int { get throws(Failure) }
            }
            protocol ItemStore: Collection<Item> {}
            """)
        ])
        let table = try #require(Modules.type("Table", in: analysis))

        #expect(Set(Modules.targets(of: table, in: analysis)) == ["Failure", "Key"])
        #expect(analysis.typeEdges.first { $0.source.path == ["ItemStore"] }?.kinds == [.refinement])
    }

    @Test("a property wrapper inside #if gives a wrapper edge")
    func conditionalWrapper() {
        let analysis = Modules.analysis("Lib", [
            ("A.swift", """
            @propertyWrapper struct Clamped { var wrappedValue: Int }
            struct Settings {
                #if DEBUG
                @Clamped
                #endif
                var level = 0
            }
            """)
        ])

        #expect(analysis.typeEdges.first { $0.source.path == ["Settings"] }?.kinds == [.wrapper])
    }

    @Test("nested and chained composition aliases expand; a class in a composition is the superclass")
    func compositions() throws {
        let analysis = Modules.analysis("Lib", [
            ("A.swift", """
            protocol Loading {}
            protocol Saving {}
            protocol Caching {}
            typealias Persisting = Loading & Saving
            typealias Services = Persisting & Caching
            typealias Store = Persisting
            struct Client: Services {}
            final class Cache: Store {}
            class Base { var count = 0 }
            protocol Themed {}
            typealias ThemedBase = Base & Themed
            final class Screen: ThemedBase { func bump() { count += 1 } }
            """)
        ])
        let screen = try #require(Modules.type("Screen", in: analysis))

        #expect(Modules.type("Loading", in: analysis)?.protocolFacts?.conformerCount == 2)
        #expect(Modules.type("Caching", in: analysis)?.protocolFacts?.conformerCount == 1)
        #expect(Modules.type("Client", in: analysis)?.coupling.ceProtocol == 3)
        #expect(Modules.type("Cache", in: analysis)?.possibleSuperclass == nil)
        #expect(screen.superclass?.path == ["Base"])
        #expect(screen.conformances.map(\.name) == ["Themed"])
        #expect(screen.cohesion.attributeCount == 1)
        #expect(Modules.type("Base", in: analysis)?.coupling.caWithinModule == 1)
    }

    @Test("@_exported inside #if in an import's attributes is read")
    func conditionalReexport() {
        let package = SwiftCodeMetrics.analyzePackage([
            SwiftCodeMetrics.analyzeModule(Modules.input("Core", [("Core.swift", "public struct Engine {}")])),
            SwiftCodeMetrics.analyzeModule(Modules.input("Networking", [
                ("Exports.swift", "#if !NO_REEXPORT\n@_exported\n#endif\nimport Core")
            ])),
            SwiftCodeMetrics.analyzeModule(Modules.input("Feature", [("Feature.swift", "import Networking")]))
        ])
        let rows = Dictionary(uniqueKeysWithValues: package.modules.map { ($0.module, $0) })

        #expect(package.moduleEdges.first { $0.source == "Networking" }?.viaExported == true)
        #expect(rows["Feature"]?.ceWithReexports == 2)
        #expect(rows["Core"]?.caWithReexports == 2)
    }
}
