//
//  TypeCouplingRuleTests.swift
//  SwiftCodeMetricsTests
//
//  The rules of Spec §9.4, §9.5 and §10.3 that the worked examples do not
//  exercise: nesting families, ceFamily, the view and namespace classes,
//  edge kinds, weak stored properties, conformances and type cycles.
//

import SwiftCodeMetrics
import Testing

@Suite("Type coupling rules (Spec §9.4, §9.5, §10.3)")
struct TypeCouplingRuleTests {
    @Test("references inside a nesting family are internalRefs; ceFamily collapses nested targets")
    func families() throws {
        let analysis = Modules.analysis("Lib", [
            ("A.swift", """
            struct Store { struct Item {} }
            struct Feature {
                struct State { var item: Store.Item }
                enum Action { case load(Store) }
                var state: State
                func reduce(_ action: Action) {}
            }
            """)
        ])
        let feature = try #require(Modules.type("Feature", in: analysis))
        let state = try #require(Modules.type("Feature.State", in: analysis))

        #expect(feature.coupling.ceTotal == 0)
        #expect(feature.coupling.internalRefs == 2)
        #expect(feature.coupling.ceFamily == 1)
        #expect(Modules.targets(of: state, in: analysis) == ["Store.Item"])
        #expect(Modules.type("Store", in: analysis)?.coupling.caWithinModule == 1)
    }

    @Test("targets are classified protocol, view, namespace or concrete, in that order")
    func targetClasses() throws {
        let analysis = Modules.analysis("Lib", [
            ("A.swift", """
            import SwiftUI
            protocol Service {}
            protocol Screen: View {}
            struct Header: View { var body: some View { Text("") } }
            struct Detail: Screen { var body: some View { Text("") } }
            enum Theme { static let accent = 1; static func color() -> Int { accent } }
            struct Model {}
            struct Page: View {
                var service: any Service
                var model: Model
                var body: some View { VStack { Header(); Detail() }.tag(Theme.color()) }
            }
            """)
        ])
        let page = try #require(Modules.type("Page", in: analysis))

        #expect(page.coupling.ceTotal == 5)
        #expect(page.coupling.ceProtocol == 1)
        #expect(page.coupling.ceView == 2)
        #expect(page.coupling.ceNamespace == 1)
        #expect(page.coupling.ceConcrete == 1)
    }

    @Test("edge kinds: inheritance, conformance, refinement, constraint, payload, typealias, wrapper")
    func edgeKinds() {
        let analysis = Modules.analysis("Lib", [
            ("A.swift", """
            protocol Base {}
            protocol Sub: Base { associatedtype Item: Base }
            class Root {}
            struct Clamp<Value> { var wrappedValue: Value }
            final class Leaf: Root, Sub {
                typealias Item = Payload
                @Clamp var limit = 0
            }
            struct Payload: Base {}
            enum Event { case send(Payload) }
            struct Box<T: Base> {}
            """)
        ])
        let kinds = Dictionary(grouping: analysis.typeEdges) { $0.source.path.joined(separator: ".") }
            .mapValues { edges in
                edges.map { edge in
                    let kinds = edge.kinds.map(\.rawValue).sorted().joined(separator: ",")
                    return edge.target.path.joined(separator: ".") + ":" + kinds
                }
            }

        #expect(kinds["Sub"] == ["Base:constraint,refinement"])
        #expect(kinds["Leaf"] == ["Clamp:wrapper", "Payload:typealias", "Root:inheritance", "Sub:conformance"])
        #expect(kinds["Event"] == ["Payload:case_payload"])
        #expect(kinds["Box"] == ["Base:constraint"])
    }

    @Test("isWeakOrUnowned only when every stored property behind the edge is weak or unowned")
    func weakEdges() {
        let analysis = Modules.analysis("Lib", [
            ("A.swift", """
            final class Node {}
            final class Weak { weak var parent: Node? }
            final class Mixed { weak var parent: Node?; var child: Node? }
            final class Plain { func make() -> Node { Node() } }
            """)
        ])
        let weak = analysis.typeEdges.first { $0.source.path == ["Weak"] }
        let mixed = analysis.typeEdges.first { $0.source.path == ["Mixed"] }
        let plain = analysis.typeEdges.first { $0.source.path == ["Plain"] }

        #expect(weak?.isWeakOrUnowned == true)
        #expect(mixed?.isWeakOrUnowned == false)
        #expect(plain?.isWeakOrUnowned == false)
    }

    @Test("typeCycles lists strongly connected components of two or more types")
    func cycles() {
        let analysis = Modules.analysis("Lib", [
            ("A.swift", """
            final class Parent { var children: [Child] = [] }
            final class Child { weak var parent: Parent?; var toy: Toy? }
            struct Toy { var owner: Owner? }
            struct Owner { var toy: Toy? }
            struct Alone {}
            """)
        ])

        #expect(analysis.typeCycles.map { $0.map { $0.path.joined(separator: ".") } } == [
            ["Child", "Parent"], ["Owner", "Toy"]
        ])
    }

    @Test("conformances: P & Q split, ~Copyable dropped, attributes unwrapped, extensions conditional")
    func conformances() throws {
        let analysis = Modules.analysis("Lib", [
            ("A.swift", """
            protocol Base {}
            protocol Sub: Base {}
            struct Box<T>: Sendable & Hashable, ~Copyable, @unchecked Sub {}
            extension Box: Equatable where T: Equatable {}
            struct Other: Base {}
            """)
        ])
        let box = try #require(Modules.type("Box", in: analysis))

        #expect(box.conformances.map(\.name) == ["Sendable", "Hashable", "Sub", "Equatable"])
        #expect(box.conformances.map(\.isConditional) == [false, false, false, true])
        #expect(box.conformances.compactMap(\.target).map(\.path) == [["Sub"]])
        #expect(box.extensions.first?.whereClause == "where T: Equatable")
        #expect(Modules.type("Base", in: analysis)?.protocolFacts?.conformerCount == 2)
        #expect(Modules.type("Sub", in: analysis)?.protocolFacts?.conformerCount == 1)
    }

    @Test("unresolved extensions are listed; extension groups are types with outgoing coupling")
    func extensions() throws {
        let analysis = Modules.analysis("Lib", [
            ("A.swift", """
            struct Feature {}
            struct Model {}
            extension Feature.State: Equatable {}
            extension String { func model() -> Model { Model() } }
            """)
        ])
        let group = try #require(Modules.type("String", in: analysis))

        #expect(analysis.unresolvedExtensions.map(\.extendedType) == ["Feature.State"])
        #expect(analysis.unresolvedExtensions.first?.conformances.map(\.name) == ["Equatable"])
        #expect(group.kind == .extensionGroup)
        #expect(group.sizes.nom == 1)
        #expect(group.coupling.ceTotal == 1)
        #expect(group.cohesion.nullReason == .notApplicableKind)
    }

    @Test("known attached macros and module-declared macros set hasKnownAttachedMacro")
    func attachedMacros() {
        let analysis = Modules.analysis("Lib", [
            ("A.swift", """
            @attached(member) macro Tracked() = #externalMacro(module: "M", type: "T")
            @Observable final class Model { var count = 0 }
            struct Plain { @Tracked var value = 0 }
            struct Bare { var value = 0 }
            """)
        ])

        #expect(Modules.type("Model", in: analysis)?.hasKnownAttachedMacro == true)
        #expect(Modules.type("Model", in: analysis)?.customAttributes == ["Observable"])
        #expect(Modules.type("Plain", in: analysis)?.hasKnownAttachedMacro == true)
        #expect(Modules.type("Bare", in: analysis)?.hasKnownAttachedMacro == false)
    }

    @Test("A.B in an expression targets the nested type A.B (Spec §7.3 step 4)")
    func nestedExpressionTarget() {
        let analysis = Modules.analysis("Lib", [
            ("A.swift", """
            enum Form { struct State { init() {} } static let shared = 0 }
            struct Screen {
                func make() -> Int { _ = Form.State(); return Form.shared }
            }
            """)
        ])

        #expect(Modules.targets(of: Modules.type("Screen", in: analysis), in: analysis) == ["Form", "Form.State"])
    }
}
