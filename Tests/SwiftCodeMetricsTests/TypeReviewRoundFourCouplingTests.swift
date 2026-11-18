//
//  TypeReviewRoundFourCouplingTests.swift
//  SwiftCodeMetricsTests
//
//  Regression tests from the fourth v0.3 review round: cohesion uses,
//  existential compositions, name counts and macro arguments (Spec §9.3,
//  §9.4).
//

import SwiftCodeMetrics
import Testing

@Suite("v0.3 review regressions, round 4: cohesion and coupling")
struct TypeReviewRoundFourCouplingTests {
    @Test("closure calls and reads find the property they reach: statics, inherited, excluded, uppercase")
    func cohesionUses() {
        let analysis = Modules.analysis("Lib", [
            ("A.swift", """
            struct Client {
                var fetch: () -> Int
                var count: Int
                static func fetch() -> Int { 0 }
                func load() -> Int { self.fetch() }
                func reload() -> Int { fetch() + 1 }
                func total() -> Int { count }
            }
            class Base { var onTap: () -> Void = {} }
            class Button: Base {
                var title = ""
                func onTap(count: Int) { title = String(count) }
                func fire() { self.onTap() }
            }
            struct Report: CustomStringConvertible {
                var title: String
                var rows: [String]
                var description: String { title }
                func description(indent: Int) -> String { rows.joined() }
                func header() -> String { title.uppercased() }
                func log() -> Int { title.count + description.count }
            }
            struct Bookmark {
                let ID: String
                var title: String
                func key() -> String { ID.lowercased() }
                func isTemporary() -> Bool { ID.hasPrefix("tmp") }
                func label() -> String { title }
            }
            """)
        ])

        #expect(Modules.type("Client", in: analysis)?.cohesion.lcom4 == 2)
        #expect(Modules.type("Client", in: analysis)?.cohesion.unusedAttributes.isEmpty == true)
        #expect(Modules.type("Button", in: analysis)?.cohesion.lcom4 == 2)
        #expect(Modules.type("Report", in: analysis)?.cohesion.lcom4 == 2)
        #expect(Modules.type("Bookmark", in: analysis)?.cohesion.lcom4 == 2)
        #expect(Modules.type("Bookmark", in: analysis)?.cohesion.unusedAttributes.isEmpty == true)
    }

    @Test("super.f(y:) lists its base name; super.$a touches the inherited attribute")
    func superDecorations() throws {
        let analysis = Modules.analysis("Lib", [
            ("A.swift", """
            @propertyWrapper
            struct Box {
                var wrappedValue: Int
                var projectedValue: Int { wrappedValue }
            }
            class Base {
                @Box var value = 0
                func update(with value: Int) {}
            }
            class Child: Base {
                var count = 0
                func total() -> Int { count }
                func apply() {
                    let handler = super.update(with:)
                    handler(count)
                }
                func projected() -> Int { super.$value }
            }
            """)
        ])
        let child = try #require(Modules.type("Child", in: analysis))

        #expect(child.cohesion.inheritedMemberRefs.contains("update"))
        #expect(child.cohesion.inheritedMemberRefs.contains("update(with:)") == false)
        #expect(child.cohesion.isolatedMembers.isEmpty)
    }

    @Test("compositions: `any` aliases name their members; platform members of an inherited alias count")
    func compositionMembers() throws {
        let analysis = Modules.analysis("App", [
            ("A.swift", """
            protocol HasAPI {}
            protocol HasStore {}
            typealias Dependencies = any HasAPI & HasStore
            final class Feature {
                let deps: Dependencies
                init(deps: Dependencies) { self.deps = deps }
            }
            protocol Fetching {}
            typealias Services = Fetching & Hashable
            struct Client: Services {}
            """)
        ])
        let feature = try #require(Modules.type("Feature", in: analysis))
        let client = try #require(Modules.type("Client", in: analysis))
        let initRecord = try #require(Modules.record("init(deps:)", in: analysis))

        #expect(feature.coupling.ceProtocol == 2)
        #expect(initRecord.typeReferences.map(\.spelling).sorted() == ["HasAPI", "HasStore"])
        #expect(client.coupling.platformNameCount == 1)
        #expect(client.declarationTypeReferences.map(\.spelling).sorted() == ["Fetching", "Hashable"])
    }

    @Test("platform names count the type: Self in a group, a member alias, an XCTest qualifier")
    func platformNames() {
        let app = Modules.analysis("App", [
            ("A.swift", """
            import Foundation
            extension String {
                func padded(to width: Int) -> Self { self }
                func trimmedCopy() -> String { self }
            }
            struct User {
                typealias ID = UUID
                let id: ID
            }
            """)
        ])
        let tests = Modules.analysis("AppTests", [
            ("LoginTests.swift", """
            import XCTest
            final class LoginTests: XCTestCase {
                func current() -> XCTest.XCTestCase { self }
            }
            """)
        ])

        #expect(Modules.type("String", in: app)?.coupling.platformNameCount == 2)
        #expect(Modules.type("User", in: app)?.coupling.platformNameCount == 1)
        #expect(Modules.type("LoginTests", in: tests)?.coupling.platformNameCount == 1)
    }

    @Test("type names in a member-level macro's arguments count")
    func macroArguments() {
        let analysis = Modules.analysis("App", [
            ("A.swift", """
            @freestanding(declaration, names: arbitrary)
            macro Register(_ type: Any.Type) = #externalMacro(module: "AppMacros", type: "RegisterMacro")
            struct Service {}
            struct Container {
                #Register(Service.self)
            }
            """)
        ])

        #expect(Modules.type("Container", in: analysis)?.coupling.ceTotal == 1)
    }
}
