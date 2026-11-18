//
//  TypeReviewRoundSixTests.swift
//  SwiftCodeMetricsTests
//
//  Regression tests from the sixth v0.3 review round: extensions written
//  through group typealiases, settling, superclasses in compositions,
//  clauses resolved outside the body, and lookups around local types and
//  unresolved extensions (Spec §2.2, §7.3, §9.1, §9.5).
//

import SwiftCodeMetrics
import Testing

@Suite("v0.3 review regressions, round 6: groups, settling and scopes")
struct TypeReviewRoundSixTests {
    @Test("an extension written through a group's typealias merges into its type, in any order")
    func groupAliasExtensions() throws {
        let analysis = Modules.analysis("App", [
            ("Owner.swift", """
            protocol Greeting {}
            struct User { let name: String }
            extension String.Owner: Greeting { func greet() -> String { name } }
            extension String { typealias Owner = User }
            extension String.Owner { struct Badge {} }
            struct Profile { let badge: User.Badge }
            """)
        ])
        let user = try #require(Modules.type("User", in: analysis))

        #expect(user.extensions.count == 2)
        #expect(user.conformances.map(\.name) == ["Greeting"])
        #expect(Modules.type("Greeting", in: analysis)?.protocolFacts?.conformerCount == 1)
        #expect(analysis.types.contains { $0.key.path == ["String", "Owner"] } == false)
        #expect(Modules.type("User.Badge", in: analysis) != nil)
        #expect(Modules.type("Profile", in: analysis)?.coupling.ceTotal == 1)
    }

    @Test("an extension reaching a private type through a group's typealias merges into that type")
    func groupAliasPrivateTypes() {
        let analysis = Modules.analysis("Lib", [
            ("A.swift", """
            private struct Token { var text = "" }
            extension String { fileprivate typealias Owner = Token }
            extension String.Owner {
                func isBlank() -> Bool {
                    if text.isEmpty { return true }
                    return false
                }
            }
            """)
        ])
        let tokens = analysis.types.filter { $0.key.path == ["Token"] }

        #expect(tokens.count == 1)
        #expect(tokens.first?.extensions.count == 1)
        #expect(tokens.first?.sizes.nom == 1)
    }

    @Test("settling sees aliases groups bring, and releases extensions that become unresolved")
    func settlingWithGroups() {
        let aliased = Modules.analysis("Lib", [
            ("A.swift", """
            class Base { struct Config {} }
            class Outer: Base {}
            struct Settings {}
            extension Outer.Config { func describe() -> String { "a" } }
            extension String { typealias Owner = Outer }
            extension String.Owner { typealias Config = Settings }
            """)
        ])
        let unresolved = Modules.analysis("App", [
            ("Feature.swift", """
            import ComposableArchitecture
            class Base { struct Config { struct State {} } }
            class Outer: Base {}
            extension Outer.Config.State { func ping() {} }
            extension Outer { typealias Config = Settings }
            @Reducer
            enum Settings {}
            """)
        ])

        #expect(Modules.type("Settings", in: aliased)?.extensions.count == 1)
        #expect(Modules.type("Base.Config", in: aliased)?.extensions.isEmpty == true)
        #expect(unresolved.unresolvedExtensions.map(\.extendedType) == ["Outer.Config.State"])
        #expect(Modules.type("Base.Config.State", in: unresolved)?.extensions.isEmpty == true)
    }

    @Test("a module class anywhere in a first-entry composition is the superclass")
    func compositionSuperclasses() throws {
        let analysis = Modules.analysis("App", [
            ("Card.swift", """
            protocol Themed {}
            class Base { var tint = 0 }
            class Card: Themed & Base {
                func paint() { tint += 1 }
            }
            """)
        ])
        let card = try #require(Modules.type("Card", in: analysis))

        #expect(card.superclass?.path == ["Base"])
        #expect(card.conformances.map(\.name) == ["Themed"])
        #expect(card.cohesion.attributeCount == 1)
    }

    @Test("extension clauses and generic constraints resolve outside the body")
    func clausesOutsideBodies() {
        let analysis = Modules.analysis("Lib", [
            ("A.swift", """
            protocol Delegate {}
            struct Plain: Delegate {}
            struct Outer { protocol Delegate {} }
            extension Outer: Delegate {}
            protocol Loading {}
            struct Store { typealias Loading = Int }
            extension Store: Loading {}
            protocol Shape {}
            struct Circle: Shape {}
            struct Canvas<Item: Shape> {
                enum Shape { case round }
                var items: [Item]
            }
            """)
        ])

        #expect(Modules.type("Delegate", in: analysis)?.protocolFacts?.conformerCount == 2)
        #expect(Modules.type("Outer.Delegate", in: analysis)?.protocolFacts?.conformerCount == 0)
        #expect(Modules.type("Loading", in: analysis)?.protocolFacts?.conformerCount == 1)
        #expect(Modules.type("Canvas", in: analysis)?.coupling.ceTotal == 1)
        #expect(Modules.type("Shape", in: analysis)?.coupling.caWithinModule == 2)
    }
}
