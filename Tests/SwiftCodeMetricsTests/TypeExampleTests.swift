//
//  TypeExampleTests.swift
//  SwiftCodeMetricsTests
//
//  Spec §16 v0.3 golden tests: every type value §12.1–12.5 states,
//  including each step's components, isolated members, unused attributes
//  and null reasons.
//

import SwiftCodeMetrics
import Testing

@Suite("Worked examples: types (Spec §12.1–12.5)")
struct TypeExampleTests {
    @Test("§12.1 an extension in another file merges into Inventory")
    func inventory() throws {
        let analysis = Modules.analysis("Shop", TypeExamples.shop)
        let inventory = try #require(Modules.type("Inventory", in: analysis))
        let item = try #require(Modules.type("Item", in: analysis))

        #expect(inventory.sizes.noa == 2)
        #expect(inventory.cohesion.attributeCount == 2)
        #expect(inventory.sizes.nom == 5)
        #expect(inventory.sizes.instanceMembers == 5)
        #expect(inventory.sizes.staticMembers == 0)
        #expect(inventory.sizes.computedProperties == 2)
        #expect(inventory.wmc.cognitive == 1)
        #expect(inventory.wmc.decisions == 1)
        #expect(inventory.cohesion.lcom4 == 1)
        #expect(Modules.components(inventory) == [
            [
                "func add(_: Item)", "func touch()", "var totalPrice: Decimal",
                "func isStale(after: TimeInterval) -> Bool"
            ]
        ])
        #expect(inventory.cohesion.excludedMembers.map(\.reason) == [.descriptionWitness])
        #expect(inventory.cohesion.isolatedMembers.isEmpty)
        #expect(inventory.cohesion.unusedAttributes.isEmpty)
        #expect(inventory.extensions.map(\.extendedType) == ["Inventory"])
        #expect(inventory.conformances.map(\.name) == ["CustomStringConvertible"])
        #expect(inventory.coupling.ceTotal == 1)
        #expect(inventory.coupling.ceConcrete == 1)
        #expect(inventory.coupling.ceFamily == 1)
        #expect(inventory.coupling.platformNameCount == 8)
        #expect(inventory.coupling.externalNameCount == 0)
        #expect(item.coupling.caWithinModule == 1)
        #expect(item.coupling.ceTotal == 0)
        let edge = try #require(analysis.typeEdges.first { $0.source == inventory.key })
        #expect(edge.kinds == [.signature, .storedProperty])
    }

    @Test("§12.1 each file alone: two members joined, or an extension group")
    func inventoryAlone() throws {
        let primary = Modules.analysis("Shop", [TypeExamples.shop[1]])
        let reporting = Modules.analysis("Shop", [TypeExamples.shop[2]])

        #expect(Modules.type("Inventory", in: primary)?.cohesion.lcom4 == 1)
        let group = try #require(Modules.type("Inventory", in: reporting))
        #expect(group.kind == .extensionGroup)
        #expect(group.cohesion.nullReason == .notApplicableKind)
    }

    @Test("§12.2 SessionController splits into two groups")
    func session() throws {
        let analysis = Modules.analysis("App", TypeExamples.session)
        let session = try #require(Modules.type("SessionController", in: analysis))

        #expect(session.sizes.noa == 4)
        #expect(session.cohesion.attributeCount == 4)
        #expect(session.sizes.nom == 7)
        #expect(session.sizes.instanceMembers == 7)
        #expect(session.sizes.initialisers == 1)
        #expect(session.sizes.computedProperties == 1)
        #expect(session.cohesion.excludedMembers.map(\.reason) == [.initializer])
        #expect(session.cohesion.lcom4 == 2)
        #expect(Modules.components(session) == [
            ["func signIn(token: String, validFor: TimeInterval)", "var isSignedIn: Bool", "func signOut()"],
            ["func record(search: String)", "func trimRecent()", "func clearSearches()"]
        ])
        #expect(session.cohesion.components.map(\.attributes) == [
            ["token", "expiry"], ["recentSearches", "maxRecent"]
        ])
        #expect(session.coupling.ceTotal == 0)
        #expect(session.coupling.platformNameCount == 6)
    }

    @Test("§12.3 PriceFormatter: null, no state use, with unused attributes")
    func formatter() throws {
        let analysis = Modules.analysis("App", TypeExamples.formatter)
        let formatter = try #require(Modules.type("PriceFormatter", in: analysis))

        #expect(formatter.sizes.noa == 2)
        #expect(formatter.sizes.nom == 3)
        #expect(formatter.sizes.instanceMembers == 2)
        #expect(formatter.sizes.staticMembers == 1)
        #expect(formatter.cohesion.lcom4 == nil)
        #expect(formatter.cohesion.nullReason == .noStateUse)
        #expect(formatter.cohesion.isolatedMembers.map(Modules.memberName) == [
            "func format(_: Decimal) -> String", "func formatRange(_: Decimal, _: Decimal) -> String"
        ])
        #expect(formatter.cohesion.excludedMembers.map(\.reason) == [.typeLevel])
        #expect(formatter.cohesion.unusedAttributes == ["currencyCode", "locale"])
        #expect(formatter.coupling.ceTotal == 0)
        #expect(formatter.coupling.platformNameCount == 3)
    }

    @Test("§12.4 ProfileLoader: Ce 3, all concrete, and no stored properties")
    func profileLoader() throws {
        let analysis = Modules.analysis("App", TypeExamples.app)
        let loader = try #require(Modules.type("ProfileLoader", in: analysis))

        #expect(loader.coupling.ceTotal == 3)
        #expect(loader.coupling.ceConcrete == 3)
        #expect(loader.coupling.ceFamily == 3)
        #expect(loader.coupling.platformNameCount == 3)
        let kinds = Dictionary(uniqueKeysWithValues: analysis.typeEdges
            .filter { $0.source == loader.key }
            .map { ($0.target.path.joined(separator: "."), $0.kinds) })
        #expect(kinds == ["APIClient": [.body], "Endpoint": [.body], "Profile": [.body, .signature]])
        for name in ["APIClient", "Endpoint", "Profile"] {
            #expect(Modules.type(name, in: analysis)?.coupling.caWithinModule == 1, "\(name)")
        }
        #expect(loader.cohesion.attributeCount == 0)
        #expect(loader.cohesion.nodeCount == 1)
        #expect(loader.cohesion.nullReason == .noStoredProperties)
    }

    @Test("§12.5 Shape: requirements, defaults and one conformer")
    func shape() throws {
        let analysis = Modules.analysis("App", TypeExamples.shapes)
        let shape = try #require(Modules.type("Shape", in: analysis))
        let facts = try #require(shape.protocolFacts)

        #expect(shape.sizes.nom == 2)
        #expect(facts.requirementCount == 2)
        #expect(facts.defaultImplementationCount == 2)
        #expect(facts.defaultsForRequirements == 0)
        #expect(facts.extensionOnlyMembers == 2)
        #expect(shape.wmc.isDefaults)
        #expect(shape.wmc.cognitive == 0)
        #expect(shape.cohesion.nullReason == .notApplicableKind)
        #expect(shape.coupling.ceTotal == 0)
        #expect(facts.conformerCount == 1)
        #expect(shape.coupling.caWithinModule == 1)
    }

    @Test("§12.5 Circle: LCOM4 1 with two isolated members, Ce 1 to the protocol")
    func circle() throws {
        let analysis = Modules.analysis("App", TypeExamples.shapes)
        let circle = try #require(Modules.type("Circle", in: analysis))

        #expect(circle.sizes.noa == 1)
        #expect(circle.sizes.nom == 4)
        #expect(circle.sizes.instanceMembers == 4)
        #expect(circle.sizes.computedProperties == 2)
        #expect(circle.cohesion.lcom4 == 1)
        #expect(Modules.components(circle) == [["var area: Double", "func scaled(by: Double) -> Circle"]])
        #expect(circle.cohesion.isolatedMembers.map(Modules.memberName) == [
            "var name: String", "func describe() -> String"
        ])
        #expect(circle.cohesion.unresolvedMemberRefs == ["summary"])
        #expect(circle.coupling.ceTotal == 1)
        #expect(circle.coupling.ceProtocol == 1)
        #expect(circle.coupling.ceFamily == 1)
        #expect(analysis.typeEdges.first { $0.source == circle.key }?.kinds == [.conformance])
    }
}
