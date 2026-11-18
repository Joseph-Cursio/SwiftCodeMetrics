//
//  TypeReviewRoundFiveTests.swift
//  SwiftCodeMetricsTests
//
//  Regression tests from the fifth v0.3 review round: settling into
//  groups, private extensions, unresolved extensions, attribute and case
//  default contexts, local inheritance clauses and module selectors (Spec
//  §2.1, §2.2, §2.3, §7.3, §9.5).
//

import SwiftCodeMetrics
import Testing

@Suite("v0.3 review regressions, round 5: groups, extensions and members")
struct TypeReviewRoundFiveTests {
    /// The extension group whose path is `path`, dot-separated.
    private static func group(_ path: String, in analysis: ModuleAnalysis) -> TypeResult? {
        analysis.types.first { $0.key.path.joined(separator: ".") == path && $0.kind == .extensionGroup }
    }

    /// The local type whose path is `path`, dot-separated.
    private static func local(_ path: String, in analysis: ModuleAnalysis) -> TypeResult? {
        analysis.types.first { $0.key.path.joined(separator: ".") == path && $0.key.localTo != nil }
    }

    @Test("a merged extension whose path settles on a platform type moves to that type's group")
    func settlingIntoGroups() throws {
        let analysis = Modules.analysis("Lib", [
            ("A.swift", """
            class Base { struct Config {} }
            class Outer: Base {}
            extension Outer.Config {
                func label() -> String {
                    if self > 0 { return "positive" }
                    return "other"
                }
            }
            extension Int { func twice() -> Int { self * 2 } }
            """),
            ("B.swift", "extension Outer { typealias Config = Int }")
        ])
        let int = try #require(Self.group("Int", in: analysis))
        let config = try #require(Modules.type("Base.Config", in: analysis))

        #expect(int.extensions.count == 2)
        #expect(int.sizes.nom == 2)
        #expect(int.wmc.cognitive == 1)
        #expect(config.extensions.isEmpty)
        #expect(config.sizes.nom == 0)
    }

    @Test("a typealias in a private extension is file-private")
    func privateExtensionAliases() throws {
        let analysis = Modules.analysis("App", [
            ("A.swift", """
            struct Store {}
            struct Row {}
            private extension Store { typealias Item = Row }
            extension Store.Item { func render() -> String { "" } }
            """),
            ("B.swift", """
            struct Cell {}
            private extension Store { typealias Item = Cell }
            """)
        ])
        let row = try #require(Modules.type("Row", in: analysis))

        #expect(row.sizes.nom == 1)
        #expect(row.extensions.count == 1)
        #expect(analysis.unresolvedExtensions.isEmpty)
    }

    @Test("an unresolved extension's records join no group another file spells the same way")
    func unresolvedExtensionRecords() throws {
        let analysis = Modules.analysis("App", [
            ("A.swift", """
            private struct Feature { var count = 0 }
            extension Feature.State {
                func summary(_ verbose: Bool) -> String {
                    if verbose { return "long" }
                    return "short"
                }
            }
            """),
            ("B.swift", """
            import Lib
            extension Feature.State { func label() -> String { "b" } }
            """)
        ])
        let state = try #require(Self.group("Feature.State", in: analysis))

        #expect(analysis.unresolvedExtensions.count == 1)
        #expect(state.sizes.nom == 1)
        #expect(state.wmc.cognitive == 0)
    }

    @Test("functions in a type's attributes, #if attribute lists and case defaults are not members")
    func attributeAndDefaultContexts() {
        let analysis = Modules.analysis("App", [
            ("A.swift", """
            import Testing
            @propertyWrapper
            struct Clamped {
                var wrappedValue: Int
                init(wrappedValue: Int, _ limit: () -> Int) { self.wrappedValue = wrappedValue }
            }
            struct Settings {
                #if DEBUG
                @Clamped({
                    func cap() -> Int { 10 }
                    return cap()
                })
                #endif
                var volume: Int = 3
                func reset() {}
            }
            @Suite(.enabled(if: { func check() -> Bool { true }; return check() }()))
            struct ParserTests {
                var input = ""
                func parse() -> Bool { input.isEmpty }
            }
            enum Shape {
                case circle(radius: Double = {
                    func base() -> Double { 1.5 }
                    return base() * 2
                }())
                case square
            }
            """)
        ])
        let settings = Modules.type("Settings", in: analysis)
        let parser = Modules.type("ParserTests", in: analysis)

        #expect(settings?.sizes.nom == 1)
        #expect(settings?.sizes.instanceMembers == 1)
        #expect(parser?.sizes.nom == 1)
        #expect(parser?.cohesion.nodeCount == 1)
        #expect(Modules.type("Shape", in: analysis)?.sizes.nom == 0)
    }

    @Test("a top-level local type's inheritance clause does not see its own nested types or aliases")
    func localInheritanceClauses() throws {
        let analysis = Modules.analysis("Lib", [
            ("A.swift", """
            class Base {}
            protocol Fetching {}
            protocol Caching {}
            func build() -> AnyObject {
                final class Local: Base {
                    final class Base {}
                }
                struct Worker: Fetching {
                    typealias Fetching = Caching
                }
                _ = Worker()
                return Local()
            }
            """)
        ])
        let local = try #require(Self.local("Local", in: analysis))

        #expect(local.coupling.ceTotal == 1)
        #expect(local.coupling.internalRefs == 0)
        #expect(Modules.type("Base", in: analysis)?.coupling.caWithinModule == 1)
        #expect(Modules.type("Fetching", in: analysis)?.protocolFacts?.conformerCount == 1)
        #expect(Modules.type("Caching", in: analysis)?.protocolFacts?.conformerCount == 0)
    }

    @Test("a type nested through a private alias of a private type stays in its family")
    func privateAliasFamilies() throws {
        let analysis = Modules.analysis("Lib", [
            ("A.swift", """
            private struct Outer {
                let inner: Inner
            }
            private typealias Box = Outer
            extension Box {
                struct Inner {
                    func attach(to owner: Outer) {}
                }
            }
            """)
        ])
        let outer = try #require(analysis.types.first { $0.key.path == ["Outer"] })

        #expect(outer.coupling.ceTotal == 0)
        #expect(outer.coupling.internalRefs == 1)
        #expect(analysis.typeEdges.isEmpty)
        #expect(analysis.typeCycles.isEmpty)
    }
}
