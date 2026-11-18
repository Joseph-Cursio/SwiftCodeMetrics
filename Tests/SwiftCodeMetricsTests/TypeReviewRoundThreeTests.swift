//
//  TypeReviewRoundThreeTests.swift
//  SwiftCodeMetricsTests
//
//  Regression tests from the third v0.3 review round: extension groups
//  reached through aliases, qualifiers and selectors, record ownership,
//  superclasses and conditional conformances (Spec §2.2, §7.3, §9.1, §9.2).
//

import SwiftCodeMetrics
import Testing

@Suite("v0.3 review regressions, round 3: groups, ownership and superclasses")
struct TypeReviewRoundThreeTests {
    @Test("a type nested in a group is reached through an alias or a module qualifier")
    func groupNestedTypes() throws {
        let analysis = Modules.analysis("App", [
            ("A.swift", """
            typealias Celsius = Double
            extension Celsius {
                enum Scale { case low, high }
            }
            extension Celsius.Scale: CustomStringConvertible {
                var description: String { "scale" }
            }
            extension Celsius.Scale {
                struct Deep {}
            }
            extension String {
                enum Limits { static func clamp(_ value: Int) -> Int { value > 80 ? 80 : value } }
            }
            """),
            ("B.swift", """
            extension Swift.String.Limits {
                static func floor(_ value: Int) -> Int { value < 0 ? 0 : value }
            }
            struct Thermometer {
                var scale: Celsius.Scale
                func limits() -> Swift.String.Limits? { nil }
            }
            """)
        ])
        let scale = try #require(Modules.type("Double.Scale", in: analysis))
        let limits = try #require(Modules.type("String.Limits", in: analysis))

        #expect(scale.kind == .enum)
        #expect(scale.sizes.nom == 1)
        #expect(scale.conformances.map(\.name) == ["CustomStringConvertible"])
        #expect(scale.coupling.caWithinModule == 1)
        #expect(Modules.type("Double.Scale.Deep", in: analysis) != nil)
        #expect(Modules.type("Celsius.Scale", in: analysis) == nil)
        #expect(limits.sizes.nom == 2)
        #expect(limits.wmc.cognitive == 2)
        #expect(Modules.type("Swift.String.Limits", in: analysis) == nil)
        #expect(Modules.targets(of: Modules.type("Thermometer", in: analysis), in: analysis)
            == ["Double.Scale", "String.Limits"])
    }

    @Test("extension Swift::Result keys like Swift.Result; Self in it is the platform Result")
    func moduleSelectorGroups() throws {
        let analysis = Modules.analysis("App", [
            ("A.swift", """
            struct Result {
                var value = 0
                func doubled() -> Int { value * 2 }
            }
            extension Swift::Result: CustomStringConvertible {
                var description: String { "result" }
                func label() -> String {
                    if case .success = self { return "ok" }
                    return "failed"
                }
            }
            extension Swift.Result {
                func identity() -> Self { self }
            }
            """)
        ])
        let result = try #require(Modules.type("Result", in: analysis))
        let group = try #require(Modules.type("Swift.Result", in: analysis))
        let identity = try #require(Modules.record("identity()", in: analysis))

        #expect(result.sizes.nom == 1)
        #expect(result.wmc.cognitive == 0)
        #expect(result.conformances.isEmpty)
        #expect(group.kind == .extensionGroup)
        #expect(group.sizes.nom == 3)
        #expect(group.wmc.cognitive == 1)
        #expect(identity.typeReferences.first { $0.spelling == "Self" }?.bucket == .platform)
    }

    @Test("file-private aliases with one name in two files send records to their own groups")
    func filePrivateAliasGroups() {
        let analysis = Modules.analysis("App", [
            ("A.swift", """
            fileprivate typealias Num = Double
            extension Num {
                func half() -> Double { self > 0 ? self / 2 : 0 }
            }
            """),
            ("B.swift", """
            fileprivate typealias Num = Int
            extension Num {
                func twice() -> Int { self > 0 ? self * 2 : 0 }
            }
            """)
        ])

        #expect(Modules.type("Double", in: analysis)?.sizes.nom == 1)
        #expect(Modules.type("Double", in: analysis)?.wmc.cognitive == 1)
        #expect(Modules.type("Int", in: analysis)?.sizes.nom == 1)
        #expect(Modules.type("Int", in: analysis)?.wmc.cognitive == 1)
    }

    @Test("a direct composition names the superclass; a superclass declared later in an extension is found")
    func superclasses() throws {
        let analysis = Modules.analysis("Lib", [
            ("A.swift", """
            protocol Themed {}
            class Base { var tint = 0 }
            final class Card: Base & Themed {
                func describe() -> Int { tint }
            }
            extension Child.Mode {
                struct Label { var text = "" }
            }
            extension Outer {
                class Parent {
                    enum Mode { case on, off }
                    var count = 0
                    func reset() {}
                }
            }
            struct Outer {}
            final class Child: Outer.Parent {
                func run() { reset() }
            }
            """)
        ])
        let card = try #require(Modules.type("Card", in: analysis))
        let child = try #require(Modules.type("Child", in: analysis))

        #expect(card.superclass?.path == ["Base"])
        #expect(card.possibleSuperclass == nil)
        #expect(card.conformances.map(\.name) == ["Themed"])
        #expect(card.cohesion.attributeCount == 1)
        #expect(child.superclass?.path == ["Outer", "Parent"])
        #expect(child.possibleSuperclass == nil)
        #expect(analysis.unresolvedExtensions.isEmpty)
        #expect(Modules.type("Outer.Parent.Mode.Label", in: analysis) != nil)
        #expect(Modules.keys(Modules.record("run()", in: analysis), .self) == ["self.reset()"])
    }

    @Test("an alias chain to a bound generic is conditional; a pass-through generic alias is not")
    func conditionalAliases() throws {
        let analysis = Modules.analysis("Lib", [
            ("A.swift", """
            protocol Summing {}
            protocol Describable {}
            protocol Listing {}
            struct Box<Value> { var value: Value }
            typealias IntBox = Box<Int>
            typealias Counts = IntBox
            extension Counts: Summing {}
            typealias Handler<T> = Box<T>
            extension Handler: Describable {}
            typealias List<T> = [T]
            extension List: Listing {}
            """)
        ])
        let box = try #require(Modules.type("Box", in: analysis))

        #expect(box.conformances.first { $0.name == "Summing" }?.isConditional == true)
        #expect(box.conformances.first { $0.name == "Describable" }?.isConditional == false)
        #expect(Modules.type("Array", in: analysis)?.conformances.first?.isConditional == false)
    }
}
