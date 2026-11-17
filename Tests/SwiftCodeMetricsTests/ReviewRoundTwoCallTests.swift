//
//  ReviewRoundTwoCallTests.swift
//  SwiftCodeMetricsTests
//
//  Regression tests from the second v0.2 review round: call keys,
//  extension groups and statics.
//

import SwiftCodeMetrics
import Testing

@Suite("v0.2 review regressions, round 2: calls and statics")
struct ReviewRoundTwoCallTests {
    @Test("module-qualified and selector calls: free functions, Self paths, unresolved types")
    func callKeyEdges() {
        let analysis = Modules.analysis("Lib", [
            ("A.swift", """
            import Foundation
            func report(_ message: String) { Foundation.NSLog(message); Foundation::NSLog(message) }
            struct Outer {
                struct Inner { init(_ value: Int) {}; static func make() -> Inner { Inner(0) } }
                func build() { _ = Self.Inner.init(1); _ = Self.Inner.make() }
            }
            enum Parser { struct Gizmo { init() {} } }
            func gizmos() { _ = Gizmo(); _ = Gizmo.init() }
            enum Clock {
                struct Date { init(timeIntervalSince1970: Double) {} }
                static func stamp() { _ = Foundation::Date.init(timeIntervalSince1970: 0) }
            }
            """)
        ])

        #expect(Modules.headline(Modules.record("report(_:)", in: analysis)) == ["free.NSLog(_:)"])
        let build = Modules.record("build()", in: analysis)
        #expect(Modules.headline(build) == ["Outer.Inner.init(_:)", "Outer.Inner.make()"])
        #expect(Modules.headline(Modules.record("gizmos()", in: analysis)) == ["Gizmo.init()"])
        let stamp = Modules.record("stamp()", in: analysis)
        #expect(Modules.headline(stamp) == ["Date.init(timeIntervalSince1970:)"])
    }

    @Test("an extension of a platform type is an extension group with members and typealiases")
    func extensionGroups() {
        let analysis = Modules.analysis("Lib", [
            ("A.swift", """
            extension String {
                typealias Transform = (Character) -> Character
                func shout() -> String { doubled() + "!" }
                func doubled() -> String { self + self }
                static func blank() -> String { "" }
                static func make() -> String { blank() }
                func mapped(_ transform: Transform) -> String { String(map(transform)) }
                func mappedLater(_ transform: Transform?) -> String { self }
            }
            """)
        ])
        func closures(_ name: String) -> [Int] {
            let parameters = Modules.record(name, in: analysis)?.parameters
            return [parameters?.closureParameterCount ?? -1, parameters?.escapingClosureParameterCount ?? -1]
        }

        #expect(Modules.headline(Modules.record("shout()", in: analysis)) == ["self.doubled()"])
        #expect(Modules.headline(Modules.record("make()", in: analysis)) == ["String.blank()"])
        #expect(closures("mapped(_:)") == [1, 0])
        #expect(closures("mappedLater(_:)") == [1, 1])
        #expect(Modules.record("shout()", in: analysis)?.typeReferences.first?.bucket == .platform)
    }

    @Test("a static property wins over a static method of the same name")
    func propertyOverMethod() {
        let analysis = Modules.analysis("Lib", [
            ("A.swift", """
            enum Limits {
                static func maximum(for key: String) -> Int { key.count }
                static let maximum = 10
                static func clamp(_ value: Int) -> Int { min(value, maximum) }
            }
            func check(_ value: Int) -> Bool { value < Limits.maximum }
            """)
        ])

        #expect(Modules.record("check(_:)", in: analysis)?.commonCoupling?.statics == ["Limits.maximum"])
        #expect(Modules.record("clamp(_:)", in: analysis)?.commonCoupling?.statics == ["Limits.maximum"])
    }

    @Test("Self.Nested.member is a static, and a singleton when it is one")
    func selfNestedStatics() {
        let record = record("use()", """
        struct Outer {
            final class Cache {
                static let shared = Cache()
                static var hits = 0
            }
            func use() -> Int {
                _ = Self.Cache.shared
                return Self.Cache.hits
            }
        }
        """)

        #expect(record?.commonCoupling?.statics == ["Outer.Cache.hits", "Outer.Cache.shared"])
        #expect(record?.commonCoupling?.mutableStatics == ["Outer.Cache.hits"])
        #expect(record?.commonCoupling?.singletons == ["Outer.Cache.shared"])
    }

    @Test("a local type in a top-level switch case resolves its own members")
    func topLevelSwitchLocalType() {
        let analysis = Modules.analysis("App", [
            ("main.swift", """
            let mode = 1
            switch mode {
            case 1:
                struct Runner {
                    func go() { step() }
                    func step() {}
                }
                Runner().go()
            default:
                break
            }
            """)
        ])

        #expect(Modules.headline(Modules.record("go()", in: analysis)) == ["self.step()"])
    }

    private func record(_ name: String, _ source: String) -> FunctionRecord? {
        Modules.record(name, in: Modules.analysis("Lib", [("A.swift", source)]))
    }
}
