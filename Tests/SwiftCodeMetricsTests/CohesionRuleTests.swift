//
//  CohesionRuleTests.swift
//  SwiftCodeMetricsTests
//
//  The rules of Spec §9.1–9.3 that the worked examples do not exercise:
//  `#if` variants, superclass attributes, whole `self`, key paths,
//  wrapper names, overloads, subscripts and witnesses.
//

import SwiftCodeMetrics
import Testing

@Suite("Cohesion and size rules (Spec §9.1–9.3)")
struct CohesionRuleTests {
    @Test("#if variants are one member; WMC takes the larger variant (Spec §2.6, §9.2)")
    func ifVariants() {
        let type = type("Probe", """
        struct Probe {
            var flag = false
            #if os(Linux)
            func check() -> Bool { if flag { return true }; return false }
            #else
            func check() -> Bool { flag }
            #endif
            func run() -> Bool { check() }
        }
        """)

        #expect(type?.sizes.nom == 2)
        #expect(type?.cohesion.nodeCount == 2)
        #expect(type?.wmc.cognitive == 1)
        #expect(type?.cohesion.lcom4 == 1)
    }

    @Test("a subclass's attributes include its in-module superclass's; inherited calls are listed")
    func superclassAttributes() throws {
        let analysis = Modules.analysis("Lib", [
            ("A.swift", """
            class Base {
                var socket = 0
                var pending = false
                func reset() {}
            }
            final class Server: Base {
                var backlog = 0
                func read() { socket += 1; reset() }
                func flush() { pending = false }
                func listen() { backlog = socket }
            }
            """)
        ])
        let server = try #require(Modules.type("Server", in: analysis))

        #expect(server.superclass?.path == ["Base"])
        #expect(server.possibleSuperclass == nil)
        #expect(server.sizes.noa == 1)
        #expect(server.cohesion.attributeCount == 3)
        #expect(server.cohesion.lcom4 == 2)
        #expect(server.cohesion.inheritedMemberRefs == ["reset"])
        #expect(server.cohesion.unusedAttributes.isEmpty)
    }

    @Test("an unresolved first inherited name of a class is its possible superclass, not a conformance")
    func possibleSuperclass() throws {
        let type = try #require(type("Model", """
        import Combine
        final class Model: ObservableObject, Sendable {
            var count = 0
        }
        """))

        #expect(type.possibleSuperclass == "ObservableObject")
        #expect(type.conformances.map(\.name) == ["Sendable"])
    }

    @Test("a whole self in a struct touches every attribute; in a class it does not (rule 6)")
    func wholeSelf() {
        let source = """
        KIND Pair: Equatable {
            var left = 0
            var right = 0
            func first() -> Int { left }
            func second() -> Int { right }
            func same(as other: Pair) -> Bool { self == other }
        }
        """
        let value = type("Pair", source.replacingOccurrences(of: "KIND", with: "struct"))
        let reference = type("Pair", source.replacingOccurrences(of: "KIND", with: "final class"))

        #expect(value?.cohesion.lcom4 == 1)
        #expect(reference?.cohesion.lcom4 == 2)
    }

    @Test("self.a, shorthand bindings, wrapper names and Self key paths touch attributes")
    func accesses() throws {
        let type = try #require(type("Settings", """
        struct Wrapper<Value> { var wrappedValue: Value; var projectedValue: Int { 0 } }
        struct Settings {
            var name: String?
            @Wrapper var level: Int
            var limit = 3
            var size = 0
            func a() -> String { self.name ?? "" }
            func b() -> Bool { if let name { return name.isEmpty }; return true }
            func c() -> Int { $level }
            func d() -> KeyPath<Settings, Int> { \\Self.limit }
            func e() -> Int { limit + _level }
            func f() -> [Int] { [1].map(\\.size) }
        }
        """))

        #expect(type.cohesion.lcom4 == 2)
        #expect(type.cohesion.rootlessKeyPathNames == ["size"])
        #expect(type.cohesion.unusedAttributes == ["size"])
        #expect(type.cohesion.isolatedMembers.map(Modules.memberName) == ["func f() -> [Int]"])
    }

    @Test("calls join overloads by labels, or by base name when no labels match; self[...] joins subscripts")
    func memberEdges() throws {
        let source = """
        struct Store {
            var items: [Int] = []
            var names: [String] = []
            func value(at index: Int) -> Int { items[index] }
            func value(named name: String) -> Int { names.count }
            func first() -> Int { value(at: 0) }
            subscript(index: Int) -> String { "" }
            func label() -> String { self[0] }
            EXTRA
        }
        """
        let exact = try #require(type("Store", source.replacingOccurrences(of: "EXTRA", with: "")))
        let fallback = try #require(type("Store", source.replacingOccurrences(
            of: "EXTRA",
            with: "func any() -> Int { self.value(for: 1) }"
        )))

        #expect(exact.cohesion.lcom4 == 2)
        #expect(Modules.components(exact) == [
            ["func value(at: Int) -> Int", "func first() -> Int"],
            ["func value(named: String) -> Int"]
        ])
        #expect(exact.cohesion.isolatedMembers.map(Modules.memberName) == [
            "subscript(_: Int) -> String", "func label() -> String"
        ])
        #expect(fallback.cohesion.lcom4 == 1)
    }

    @Test("whole-value and description witnesses, init, static and observers are excluded")
    func exclusions() throws {
        let type = try #require(type("Point", """
        struct Point: Hashable, Codable, CustomStringConvertible {
            var x = 0 { didSet { print(x) } }
            var y = 0
            init() {}
            static func origin() -> Point { Point() }
            func hash(into hasher: inout Hasher) { hasher.combine(x) }
            var hashValue: Int { x }
            func encode(to encoder: Encoder) throws {}
            var description: String { "\\(x)" }
            func length() -> Int { x + y }
        }
        """))

        #expect(type.cohesion.excludedMembers.map(\.reason) == [
            .observer, .initializer, .typeLevel, .wholeValueWitness, .wholeValueWitness, .wholeValueWitness,
            .descriptionWitness
        ])
        #expect(type.sizes.nom == 7)
        #expect(type.cohesion.nodeCount == 1)
    }

    @Test("stored property facts and enum case counts (Spec §9.1)")
    func storedProperties() throws {
        let analysis = Modules.analysis("Lib", [
            ("A.swift", """
            final class Holder {
                let id: Int = 0
                lazy var cache: [String] = []
                weak var owner: Holder?
                var count = 0 { willSet {} }
                @MainActor var title = ""
                static var shared = 0
                var computed: Int { count }
            }
            enum Token { case word(String), number(Int), end }
            """)
        ])
        let holder = try #require(Modules.type("Holder", in: analysis))
        let facts = holder.sizes.storedProperties

        #expect(facts.map(\.name) == ["id", "cache", "owner", "count", "title"])
        #expect(facts.map(\.isLet) == [true, false, false, false, false])
        #expect(facts.map(\.isLazy) == [false, true, false, false, false])
        #expect(facts.map(\.isWeakOrUnowned) == [false, false, true, false, false])
        #expect(facts.map(\.hasObservers) == [false, false, false, true, false])
        #expect(facts.last?.attributeNames == ["MainActor"])
        #expect(facts.first?.typeText == "Int")
        #expect(holder.sizes.caseCount == nil)
        #expect(Modules.type("Token", in: analysis)?.sizes.caseCount == 3)
    }

    private func type(_ name: String, _ source: String) -> TypeResult? {
        Modules.type(name, in: Modules.analysis("Lib", [("A.swift", source)]))
    }
}
