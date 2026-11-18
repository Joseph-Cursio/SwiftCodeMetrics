//
//  TypeReviewRoundFourTests.swift
//  SwiftCodeMetricsTests
//
//  Regression tests from the fourth v0.3 review round: extension merge
//  order, group keys, selectors, member typealiases, inheritance-clause
//  scope and members (Spec §2.2, §2.3, §7.3, §9.1).
//

import SwiftCodeMetrics
import Testing

@Suite("v0.3 review regressions, round 4: groups, extensions and members")
struct TypeReviewRoundFourTests {
    @Test("private member typealiases are seen only in their file")
    func privateMemberAliases() throws {
        let analysis = Modules.analysis("App", [
            ("Screen.swift", """
            struct Config {}
            struct Model {}
            struct Screen {
                func render(config: Config) {}
            }
            extension Screen {
                private typealias Item = Model
                func make() -> Item { Item() }
            }
            """),
            ("Screen+Theme.swift", """
            struct ThemeConfig {}
            struct Other {}
            extension Screen {
                private typealias Config = ThemeConfig
                private typealias Item = Other
                func applyTheme(_ config: Config) {}
                func build() -> Item { Item() }
            }
            """)
        ])
        let screen = try #require(Modules.type("Screen", in: analysis))
        let render = try #require(Modules.record("render(config:)", in: analysis))

        #expect(render.typeReferences.first?.target?.path == ["Config"])
        #expect(screen.ambiguousTypeRefs.isEmpty)
        #expect(Modules.targets(of: screen, in: analysis) == ["Config", "Model", "Other", "ThemeConfig"])
    }
}
