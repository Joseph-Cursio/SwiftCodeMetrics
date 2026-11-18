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
}
