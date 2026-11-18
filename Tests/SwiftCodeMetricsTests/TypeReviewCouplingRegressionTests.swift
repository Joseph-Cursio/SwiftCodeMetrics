//
//  TypeReviewCouplingRegressionTests.swift
//  SwiftCodeMetricsTests
//
//  Regression tests from the first v0.3 review round: cohesion accesses,
//  ce references and edge kinds, conformances and the module level
//  (Spec §9.3–9.5, §10).
//

import SwiftCodeMetrics
import Testing

@Suite("v0.3 review regressions: cohesion, coupling and modules")
struct TypeReviewCouplingRegressionTests {
    @Test("calling a stored closure property touches it; a property read does not join a same-named method")
    func closureCallsAndPropertyReads() {
        let analysis = Modules.analysis("Lib", [
            ("A.swift", """
            struct Debouncer {
                let action: () -> Void
                var delay = 0.5
                func fire() { action() }
                func fireLater() { self.action() }
                func wait() -> Double { delay }
            }
            struct Tally {
                var count = 0
                var names: [String] = []
                func count(where predicate: (String) -> Bool) -> Int { names.filter(predicate).count }
                func bump() -> Int { count + 1 }
            }
            """)
        ])

        #expect(Modules.type("Debouncer", in: analysis)?.cohesion.lcom4 == 2)
        #expect(Modules.type("Debouncer", in: analysis)?.cohesion.unusedAttributes.isEmpty == true)
        #expect(Modules.type("Tally", in: analysis)?.cohesion.lcom4 == 2)
    }

    @Test("self.$a and self._a touch a (rule 4)")
    func wrapperSelfMembers() throws {
        let type = try #require(type("Meter", """
        @propertyWrapper struct Clamped {
            var wrappedValue: Int
            var projectedValue: Int { wrappedValue }
        }
        struct Meter {
            @Clamped var level: Int
            var unit: String
            func raw() -> Int { self._level.wrappedValue }
            func projected() -> Int { self.$level }
            func label() -> String { unit }
        }
        """))

        #expect(type.cohesion.lcom4 == 2)
        #expect(type.cohesion.unresolvedMemberRefs.isEmpty)
    }

    @Test("protocol requirement signatures are names the protocol uses; requirement generics are not")
    func requirementSignatures() throws {
        let analysis = Modules.analysis("App", [
            ("A.swift", """
            final class Model {
                weak var delegate: ModelDelegate?
            }
            enum LoadError: Error {}
            protocol ModelDelegate: AnyObject {
                func modelDidChange(_ model: Model) throws(LoadError)
                var current: Model? { get }
                func convert<Output>(_ value: Output) -> Output
            }
            """)
        ])
        let delegate = try #require(Modules.type("ModelDelegate", in: analysis))

        #expect(Set(Modules.targets(of: delegate, in: analysis)) == ["LoadError", "Model"])
        #expect(delegate.coupling.externalNameCount == 0)
        #expect(analysis.typeCycles.map { $0.map { $0.path.joined(separator: ".") } } == [["Model", "ModelDelegate"]])
    }

    @Test("a generic member typealias's own parameters are not references")
    func genericTypealias() throws {
        let type = try #require(type("Pipeline", """
        struct Item {}
        struct Pipeline {
            typealias Transform<Item> = (Item) -> Item
            typealias Callback<Fetched> = (Fetched) -> Void
        }
        """))

        #expect(type.coupling.ceTotal == 0)
        #expect(type.coupling.externalNameCount == 0)
    }

    @Test("A.B targets the nested type under a platform type, a module qualifier, Self, or a specialisation")
    func nestedExpressionTargets() {
        let analysis = Modules.analysis("Shop", [
            ("A.swift", """
            extension String {
                enum Limits { static let maxLength = 80 }
            }
            enum Form { struct State { init() {} } }
            struct Box<T> { struct Item { init() {} } }
            class Base { struct Config { init() {} } }
            struct Validator {
                func check(_ text: String) -> Bool { text.count <= String.Limits.maxLength }
            }
            struct Screen {
                func make() { _ = Shop.Form.State(); _ = Shop::Form.State() }
            }
            struct Maker {
                func make() -> Any { Box<Int>.Item() }
            }
            final class Child: Base {
                func make() { _ = Self.Config() }
            }
            struct Feature {
                struct State { init() {} }
                func reset() { _ = Self.State() }
            }
            """)
        ])

        #expect(Modules.targets(of: Modules.type("Validator", in: analysis), in: analysis) == ["String.Limits"])
        #expect(Modules.type("Validator", in: analysis)?.coupling.ceNamespace == 1)
        #expect(Modules.targets(of: Modules.type("Screen", in: analysis), in: analysis) == ["Form.State"])
        #expect(Modules.targets(of: Modules.type("Maker", in: analysis), in: analysis) == ["Box.Item"])
        #expect(Modules.targets(of: Modules.type("Child", in: analysis), in: analysis) == ["Base", "Base.Config"])
        #expect(Modules.type("Feature", in: analysis)?.coupling.internalRefs == 1)
    }

    @Test("typealias compositions expand into conformances; generic arguments take the entry's kind")
    func compositionsAndEntryKinds() {
        let analysis = Modules.analysis("Lib", [
            ("A.swift", """
            protocol Loading {}
            protocol Saving {}
            typealias Persisting = Loading & Saving
            struct Store: Persisting {}
            final class Cache: Persisting {}
            protocol Feature: Persisting {}
            struct Screen: Feature {}
            protocol RowModel {}
            class BaseList<Row> {}
            final class ListController: BaseList<any RowModel> {}
            """)
        ])

        #expect(Modules.type("Loading", in: analysis)?.protocolFacts?.conformerCount == 3)
        #expect(Modules.type("Saving", in: analysis)?.protocolFacts?.conformerCount == 3)
        #expect(Modules.type("Cache", in: analysis)?.possibleSuperclass == nil)
        #expect(Modules.type("Store", in: analysis)?.coupling.ceProtocol == 2)
        let list = analysis.typeEdges.filter { $0.source.path == ["ListController"] }
        #expect(list.map(\.kinds) == [[.inheritance], [.inheritance]])
    }

    @Test("bound-generic and unresolved extensions report conditional conformances and their targets")
    func conditionalConformances() throws {
        let analysis = Modules.analysis("Lib", [
            ("A.swift", """
            protocol Summing {}
            protocol Resettable {}
            struct Box<Value> { var value: Value }
            extension Box<Int>: Summing {}
            struct Feature<Value> {}
            extension Feature.State: Resettable {}
            extension Feature.Action: Equatable where Value: Equatable {}
            """)
        ])
        let box = try #require(Modules.type("Box", in: analysis))

        #expect(box.conformances.map(\.isConditional) == [true])
        #expect(analysis.unresolvedExtensions.map { $0.conformances.map(\.target?.path) } == [[["Resettable"]], [nil]])
        #expect(analysis.unresolvedExtensions.map { $0.conformances.map(\.isConditional) } == [[false], [true]])
    }

    @Test("a backticked module name in an import names the module")
    func backtickedImport() {
        let package = SwiftCodeMetrics.analyzePackage([
            SwiftCodeMetrics.analyzeModule(Modules.input("Core", [("Core.swift", "public struct Point {}")])),
            SwiftCodeMetrics.analyzeModule(Modules.input("App", [("App.swift", "import `Core`")]))
        ])
        let rows = Dictionary(uniqueKeysWithValues: package.modules.map { ($0.module, $0) })

        #expect(rows["App"]?.cePackage == 1)
        #expect(rows["Core"]?.caDirect == 1)
        #expect(package.moduleEdges.map(\.target) == ["Core"])
    }

    private func type(_ name: String, _ source: String) -> TypeResult? {
        Modules.type(name, in: Modules.analysis("Lib", [("A.swift", source)]))
    }
}
