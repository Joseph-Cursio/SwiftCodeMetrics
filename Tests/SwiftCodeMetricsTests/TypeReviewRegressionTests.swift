//
//  TypeReviewRegressionTests.swift
//  SwiftCodeMetricsTests
//
//  Regression tests from the first v0.3 review round: members, protocol
//  requirements, cases and attributes (Spec §2.3, §9.1, §9.2).
//

import SwiftCodeMetrics
import Testing

@Suite("v0.3 review regressions: sizes and members")
struct TypeReviewRegressionTests {
    @Test("protocol requirements differing in labels or types are separate; defaults match by labels")
    func protocolRequirements() throws {
        let analysis = Modules.analysis("Lib", [
            ("A.swift", """
            protocol Store {
                init()
                init(capacity: Int)
                subscript(index: Int) -> Int { get }
                subscript(key: String) -> Int { get }
                func handle(_ value: Int)
                func handle(_ value: String)
            }
            protocol Entity {
                init(id: Int)
                subscript(row: Int, column: Int) -> Int { get }
            }
            extension Entity {
                init() { self.init(id: 0) }
                subscript(point: (Int, Int)) -> Int { self[point.0, point.1] }
            }
            """)
        ])
        let store = try #require(Modules.type("Store", in: analysis))
        let entity = try #require(Modules.type("Entity", in: analysis)?.protocolFacts)

        #expect(store.sizes.nom == 6)
        #expect(store.sizes.initialisers == 2)
        #expect(store.sizes.subscripts == 2)
        #expect(store.protocolFacts?.requirementCount == 6)
        #expect(entity.defaultsForRequirements == 0)
        #expect(entity.extensionOnlyMembers == 2)
    }

    @Test("same-text private members in two files are two members, and WMC adds them")
    func privateMembersInTwoFiles() throws {
        let analysis = Modules.analysis("Lib", [
            ("A.swift", """
            struct Probe {
                var flag = false
                func run() {}
                private func helper() -> Bool { if flag { return true }; return false }
            }
            """),
            ("B.swift", """
            extension Probe {
                #if DEBUG
                private func helper() -> Bool { if flag { if !flag { return true } }; return false }
                #endif
            }
            """)
        ])
        let probe = try #require(Modules.type("Probe", in: analysis))

        #expect(probe.sizes.nom == 3)
        #expect(probe.wmc.cognitive == 4)
    }

    @Test("a func inside a stored property's initial value is not a member, but counts in WMC")
    func initialValueFunctions() throws {
        let type = try #require(type("Config", """
        struct Config {
            var a = 0
            static let table: [Int] = {
                func square(_ value: Int) -> Int { if value > 0 { return value * value }; return 0 }
                return [1, 2, 3].map(square)
            }()
            func first() -> Int { a }
        }
        """))

        #expect(type.sizes.nom == 1)
        #expect(type.cohesion.nodeCount == 1)
        #expect(type.cohesion.nullReason == .fewerThanTwoMembers)
        #expect(type.wmc.cognitive == 1)
    }

    @Test("an attached macro inside #if in the attribute list is read")
    func conditionalAttribute() throws {
        let type = try #require(type("Model", """
        #if canImport(Observation)
        @Observable
        #endif
        final class Model {
            var count = 0
        }
        """))

        #expect(type.customAttributes == ["Observable"])
        #expect(type.hasKnownAttachedMacro)
    }

    @Test("extension Swift.String and extension String form one group")
    func qualifiedExtensionGroup() {
        let analysis = Modules.analysis("App", [
            ("A.swift", """
            extension String {
                func shout() -> String { uppercased() }
            }
            extension Swift.String {
                func whisper() -> String { lowercased() }
            }
            """)
        ])
        let groups = analysis.types.filter { $0.kind == .extensionGroup }

        #expect(groups.map(\.key.path) == [["String"]])
        #expect(groups.first?.sizes.nom == 2)
        #expect(groups.first?.extensions.count == 2)
    }

    @Test("cases sharing a base name with different labels are counted apart")
    func caseLabels() {
        let type = type("Command", """
        enum Command {
            case move(x: Int)
            case move(dx: Int)
            case stop
        }
        """)

        #expect(type?.sizes.caseCount == 3)
    }

    private func type(_ name: String, _ source: String) -> TypeResult? {
        Modules.type(name, in: Modules.analysis("Lib", [("A.swift", source)]))
    }
}
