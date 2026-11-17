//
//  ReviewRoundTwoTests.swift
//  SwiftCodeMetricsTests
//
//  Regression tests from the second v0.2 review round.
//

import SwiftCodeMetrics
import Testing

@Suite("v0.2 review regressions, round 2")
struct ReviewRoundTwoTests {
    @Test("local types in unscored initial values never merge with module types")
    func contextLocalTypes() {
        let analysis = Modules.analysis("Lib", [
            ("A.swift", """
            func helper() -> Int { 1 }
            func log() {}
            struct Formatter { func render() -> Int { helper() } }
            struct Helper { func run() { log() } }
            """),
            ("B.swift", """
            struct Settings {
                static let value: Int = {
                    struct Formatter { func helper() -> Int { 2 } }
                    struct Helper { func log() {} }
                    return Formatter().helper()
                }()
            }
            """)
        ])

        #expect(Modules.headline(Modules.record("render()", in: analysis)) == ["free.helper()"])
        #expect(Modules.headline(Modules.record("run()", in: analysis)) == ["free.log()"])
    }

    @Test("backticked statics match their references")
    func backtickedNames() {
        let record = record("isVerbose()", """
        final class Settings {
            static let `default` = Settings()
            var verbose = false
        }
        func isVerbose() -> Bool { Settings.default.verbose }
        """)

        #expect(record?.commonCoupling?.statics == ["Settings.default"])
        #expect(record?.commonCoupling?.singletons == ["Settings.default"])
    }

    @Test("a local type sees the nested types of its enclosing local type and of the function's type")
    func localTypeChains() {
        let analysis = Modules.analysis("Lib", [
            ("A.swift", """
            func build() -> Int {
                struct Outer {
                    struct Part { static let size = 2 }
                    struct Builder { func make() -> Int { Part.size } }
                }
                return Outer.Builder().make()
            }
            struct Shell {
                struct Inner {}
                func make() -> Int {
                    struct Local { func assemble() -> Inner { Inner() } }
                    _ = Local().assemble()
                    return 0
                }
            }
            """)
        ])
        let make = Modules.record("make()", in: analysis)
        let assemble = Modules.record("assemble()", in: analysis)

        #expect(make?.commonCoupling?.statics == ["Outer.Part.size"])
        #expect(Modules.headline(assemble) == ["Shell.Inner.init()"])
        #expect(assemble?.typeReferences.allSatisfy { $0.target?.path == ["Shell", "Inner"] } == true)
    }

    @Test("a bare call of a static closure property is a static reference")
    func staticClosureCall() {
        let record = record("save()", """
        enum Hooks {
            static var onSave: () -> Void = {}
            static func save() { onSave() }
        }
        """)

        #expect(record?.commonCoupling?.statics == ["Hooks.onSave"])
        #expect(record?.commonCoupling?.mutableStatics == ["Hooks.onSave"])
    }

    @Test("Lib::counter is a module global")
    func moduleSelectorGlobal() {
        let record = record("current()", "var counter = 0\nfunc current() -> Int { Lib::counter }")

        #expect(record?.commonCoupling?.globals == ["counter"])
        #expect(record?.commonCoupling?.mutableGlobals == ["counter"])
    }

    @Test("a typed throws type is a signature reference")
    func typedThrows() {
        let analysis = Modules.analysis("Lib", [
            ("A.swift", """
            struct ParseError: Error {}
            struct Loader {
                init(path: String) throws(ParseError) {}
                func load() throws(ParseError) -> Int { 0 }
            }
            """)
        ])

        for name in ["load()", "init(path:)"] {
            let references = Modules.record(name, in: analysis)?.typeReferences ?? []
            let thrown = references.filter { $0.spelling == "ParseError" }
            #expect(thrown.map(\.bucket) == [.module])
            #expect(thrown.map(\.edgeKind) == [.signature])
        }
    }

    @Test("Module.Type in an expression is a type reference by that module")
    func moduleQualifiedTypes() {
        let analysis = Modules.analysis("Shop", [
            ("A.swift", """
            import Foundation
            struct Item {}
            func stamp() {
                _ = Foundation.Date()
                _ = Shop.Item()
                _ = Foundation::Date()
            }
            """)
        ])
        let references = Modules.record("stamp()", in: analysis)?.typeReferences ?? []
        let buckets = references.map { "\($0.spelling) \($0.bucket?.rawValue ?? "-")" }

        #expect(buckets == ["Date platform", "Item module", "Date platform"])
    }

    @Test("typealias expansion resolves from the alias's own position, with its own generic parameters")
    func typealiasPositions() {
        let analysis = Modules.analysis("Lib", [
            ("A.swift", """
            struct Item {}
            typealias Thing = Item
            func make() {
                struct Item {}
                func use(_ value: Thing) {}
            }
            protocol Keyed { associatedtype Key }
            struct User: Keyed { typealias Key = Int }
            typealias KeyOf<Model: Keyed> = Model.Key
            func lookup(_ key: KeyOf<User>) {}
            """)
        ])

        let use = Modules.record("use(_:)", in: analysis)
        #expect(use?.typeReferences.first?.target == TypeKey(module: "Lib", path: ["Item"]))
        #expect(Modules.record("lookup(_:)", in: analysis)?.typeReferences.map(\.spelling) == ["User"])
    }

    @Test("a type nested in a local type sees its siblings")
    func nestedLocalSiblings() {
        let record = record("describe(_:)", """
        func decode() {
            struct Payload {
                enum Kind { case a, b }
                struct Meta { func describe(_ kind: Kind) -> String { "" } }
            }
        }
        """)

        #expect(record?.typeReferences.first?.target?.path == ["Payload", "Kind"])
        #expect(record?.typeReferences.first?.target?.localTo != nil)
    }

    @Test("element types inside a sugared base of a member type count")
    func sugaredMemberBase() {
        let record = record("pick(_:in:)", """
        struct Item {}
        func pick(_ position: [Item].Index, in values: [String: Item].Values) {}
        """)

        let expected = ["Array.Index", "Item", "Dictionary.Values", "String", "Item"]
        #expect(record?.typeReferences.map(\.spelling) == expected)
    }

    private func record(_ name: String, _ source: String) -> FunctionRecord? {
        Modules.record(name, in: Modules.analysis("Lib", [("A.swift", source)]))
    }
}
