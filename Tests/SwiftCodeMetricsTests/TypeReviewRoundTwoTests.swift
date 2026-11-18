//
//  TypeReviewRoundTwoTests.swift
//  SwiftCodeMetricsTests
//
//  Regression tests from the second v0.3 review round: extension group
//  keys, members and requirements (Spec §2.2, §2.3, §9.1).
//

import SwiftCodeMetrics
import Testing

@Suite("v0.3 review regressions, round 2: groups and members")
struct TypeReviewRoundTwoTests {
    @Test("extension groups are keyed by the resolved type, never by a module type's key")
    func groupKeys() throws {
        let analysis = Modules.analysis("App", [
            ("A.swift", """
            import Foundation
            import SwiftUI
            enum Result { case ok, failed }
            extension Swift.Result: CustomStringConvertible {
                var description: String { "result" }
            }
            extension Swift.String {
                enum Limits { static func clamp(_ value: Int) -> Int { value } }
            }
            extension String.Limits {
                static func floor(_ value: Int) -> Int { value }
            }
            extension SwiftUI.View { func framed() -> Int { 0 } }
            extension View { func padded() -> Int { 0 } }
            typealias Celsius = Double
            extension Celsius { func toFahrenheit() -> Double { self } }
            extension Double { func half() -> Double { self } }
            struct User { typealias ID = UUID }
            extension User.ID { static func placeholder() -> Int { 0 } }
            struct Validator { func check() -> Int { String.Limits.clamp(1) } }
            """)
        ])
        let result = try #require(Modules.type("Result", in: analysis))

        #expect(result.kind == .enum)
        #expect(result.sizes.nom == 0)
        #expect(result.extensions.isEmpty)
        #expect(Modules.type("Swift.Result", in: analysis)?.kind == .extensionGroup)
        #expect(Modules.type("String.Limits", in: analysis)?.sizes.nom == 2)
        #expect(Modules.type("View", in: analysis)?.sizes.nom == 2)
        #expect(Modules.type("Double", in: analysis)?.sizes.nom == 2)
        #expect(Modules.type("UUID", in: analysis)?.sizes.nom == 1)
        #expect(analysis.unresolvedExtensions.isEmpty)
        #expect(Modules.targets(of: Modules.type("Validator", in: analysis), in: analysis) == ["String.Limits"])
    }

    @Test("#if property requirements of different types are two; operator defaults match by arity")
    func requirements() {
        let analysis = Modules.analysis("App", [
            ("A.swift", """
            protocol Themed {
            #if canImport(UIKit)
                var tint: UIColor { get }
            #else
                var tint: NSColor { get }
            #endif
                func refresh() -> Int
            }
            protocol Vector {
                static func + (lhs: Self, rhs: Self) -> Self
            }
            extension Vector {
                static func + (left: Self, right: Self) -> Self { left }
            }
            """)
        ])

        #expect(Modules.type("Themed", in: analysis)?.sizes.nom == 3)
        #expect(Modules.type("Themed", in: analysis)?.protocolFacts?.requirementCount == 3)
        #expect(Modules.type("Vector", in: analysis)?.protocolFacts?.defaultsForRequirements == 1)
    }

    @Test("members: initial-value functions with selectors, private #if subscripts in two files")
    func members() throws {
        let analysis = Modules.analysis("Lib", [
            ("Grid.swift", """
            struct Grid {
                var cells: [Int] = []
                static let format: (Int) -> String = {
                    func pad(_ value: Lib::Int) -> String { String(value) }
                    return { pad($0) }
                }()
            }
            struct Int {}
            extension Grid {
            #if DEBUG
                private subscript(debug index: Swift.Int) -> Swift.Int {
                    get { if index < 0 { return 0 }; return cells[index] }
                    set { cells[index] = newValue }
                }
            #endif
            }
            """),
            ("GridDebug.swift", """
            extension Grid {
            #if DEBUG
                private subscript(debug index: Swift.Int) -> Swift.Int {
                    get { if index < 0 { return 0 }; return cells[index] }
                    set { cells[index] = newValue }
                }
            #endif
            }
            """)
        ])
        let grid = try #require(Modules.type("Grid", in: analysis))

        #expect(grid.sizes.nom == 2)
        #expect(grid.sizes.subscripts == 2)
        #expect(grid.wmc.cognitive == 2)
    }

    @Test("var a, b: Int gives both facts their type; an extension of a bound-generic alias is conditional")
    func typeTextAndBoundAlias() {
        let analysis = Modules.analysis("Lib", [
            ("A.swift", """
            struct Point { var x, y: Int }
            protocol Summing {}
            struct Box<Value> { var value: Value }
            typealias IntBox = Box<Int>
            extension IntBox: Summing {}
            """)
        ])

        #expect(Modules.type("Point", in: analysis)?.sizes.storedProperties.map(\.typeText) == ["Int", "Int"])
        #expect(Modules.type("Box", in: analysis)?.conformances.map(\.isConditional) == [true])
    }

    @Test("a caseless all-static enum with #warning is still a namespace")
    func namespaceWithMacro() {
        let analysis = Modules.analysis("Lib", [
            ("A.swift", """
            enum Keys {
                #warning("tidy up")
                static let name = "name"
            }
            struct User { func key() -> String { Keys.name } }
            """)
        ])

        #expect(Modules.type("User", in: analysis)?.coupling.ceNamespace == 1)
    }
}
