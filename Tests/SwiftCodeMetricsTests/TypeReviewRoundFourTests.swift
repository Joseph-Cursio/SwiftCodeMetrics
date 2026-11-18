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
    /// The extension group whose path is `path`, dot-separated.
    private static func group(_ path: String, in analysis: ModuleAnalysis) -> TypeResult? {
        analysis.types.first { $0.key.path.joined(separator: ".") == path && $0.kind == .extensionGroup }
    }

    @Test("an extension settles on the type its path names in the finished table")
    func extensionsSettle() throws {
        let analysis = Modules.analysis("Lib", [
            ("A.swift", """
            class Base { struct Config {} }
            class Outer: Base {}
            struct Settings {}
            extension Outer.Config: Equatable { func f() -> Int { 1 } }
            extension Outer { typealias Config = Settings }
            """)
        ])
        let settings = try #require(Modules.type("Settings", in: analysis))
        let config = try #require(Modules.type("Base.Config", in: analysis))

        #expect(settings.sizes.nom == 1)
        #expect(settings.extensions.count == 1)
        #expect(settings.conformances.map(\.name) == ["Equatable"])
        #expect(config.sizes.nom == 0)
        #expect(config.extensions.isEmpty)
        #expect(config.conformances.isEmpty)
    }

    @Test("records go to the group their extension registers in, next to a private type named like it")
    func groupsBesidePrivateTypes() throws {
        let analysis = Modules.analysis("App", [
            ("A.swift", """
            private struct Result { var value: Int }
            extension Swift.Result {
                func describe(_ verbose: Bool) -> String {
                    if verbose { return "long" }
                    return "short"
                }
            }
            """),
            ("B.swift", """
            extension Result {
                var isSuccess: Bool {
                    if case .success = self { return true }
                    return false
                }
            }
            """)
        ])
        let qualified = try #require(Self.group("Swift.Result", in: analysis))
        let bare = try #require(Self.group("Result", in: analysis))

        #expect(qualified.sizes.nom == 1)
        #expect(qualified.wmc.cognitive == 1)
        #expect(bare.sizes.nom == 1)
        #expect(bare.wmc.cognitive == 1)
    }

    @Test("a type nested in a group through an alias waits for the table; a module's own selector drops")
    func nestedGroupsAndSelectors() throws {
        let gauge = Modules.analysis("App", [
            ("A.swift", """
            extension Double { enum Unit {} }
            extension Double.Unit { enum Sub {} }
            typealias Gauge = Swift.Double.Unit.Sub
            extension Gauge {
                struct Needle { func read() -> Int { 1 } }
            }
            """)
        ])
        let shop = Modules.analysis("Shop", [
            ("Shop.swift", "struct Shop { var name: String }\nstruct Item { var price: Int }\n"),
            ("Item+Discount.swift", """
            extension Shop::Item {
                func discounted(_ flag: Bool) -> Int {
                    if flag { return price - 1 }
                    return price
                }
            }
            """)
        ])
        let item = try #require(Modules.type("Item", in: shop))

        #expect(Modules.type("Double.Unit.Sub.Needle", in: gauge)?.sizes.nom == 1)
        #expect(Modules.type("Gauge.Needle", in: gauge) == nil)
        #expect(item.extensions.count == 1)
        #expect(item.sizes.nom == 1)
        #expect(item.wmc.cognitive == 1)
        #expect(shop.unresolvedExtensions.isEmpty)
    }

    @Test("extension Swift::Result resolves its clause from the group, not the module's Result")
    func selectorExtensionClauses() throws {
        let analysis = Modules.analysis("App", [
            ("A.swift", """
            protocol Convertible {}
            struct Result {
                protocol Convertible {}
            }
            extension Swift::Result: Convertible {}
            """)
        ])
        let group = try #require(Self.group("Swift.Result", in: analysis))

        #expect(group.conformances.first?.target?.path == ["Convertible"])
        #expect(Modules.type("Convertible", in: analysis)?.coupling.caWithinModule == 1)
        #expect(Modules.type("Result.Convertible", in: analysis)?.coupling.caWithinModule == 0)
    }

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
