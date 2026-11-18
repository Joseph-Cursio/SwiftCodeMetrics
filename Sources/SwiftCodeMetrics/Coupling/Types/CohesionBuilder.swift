//
//  CohesionBuilder.swift
//  SwiftCodeMetrics
//
//  LCOM4 for one type (Spec §9.3): nodes, accesses, member edges,
//  connected components, attribute-free components and null reasons.
//

/// Computes one type's cohesion.
struct CohesionBuilder {
    /// The kinds LCOM4 is defined for.
    private static let applicableKinds: Set<TypeKind> = [.actor, .class, .struct]
    /// Whole-value witnesses: base name and labels.
    private static let wholeValueWitnesses: Set<MemberCall> = [
        MemberCall(name: "encode", labels: ["to"]),
        MemberCall(name: "hash", labels: ["into"]),
        MemberCall(name: "hashValue", labels: [])
    ]
    /// Description witnesses.
    private static let descriptionWitnesses: Set<String> = ["customMirror", "debugDescription", "description"]
    /// The fewest nodes a graph needs for LCOM4 to be defined.
    private static let minimumNodes = 2

    /// The type's kind.
    let kind: TypeKind
    /// Own stored instance properties, in declaration order.
    let ownAttributes: [String]
    /// Stored instance properties of in-module superclasses.
    let inheritedAttributes: [String]
    /// The type's members.
    let groups: [MemberGroup]
    /// Per-record facts.
    let facts: [RecordFacts?]
    /// The options.
    let options: CohesionOptions
    /// The extension a member is declared in; nil for the primary declaration.
    let declaringExtension: (MemberGroup) -> ExtensionFact?

    /// Own computed instance properties, excluded ones (`description`) included.
    private var ownComputed: Set<String> {
        Set(groups.filter { $0.role == .computedProperty && $0.isTypeLevel == false }.map(\.baseName))
    }

    /// The result for an enum, protocol or extension group: no graph.
    private static func notApplicable(noa: Int, attributeCount: Int) -> CohesionResult {
        CohesionResult(
            lcom4: nil,
            nullReason: .notApplicableKind,
            components: [],
            isolatedMembers: [],
            excludedMembers: [],
            unusedAttributes: [],
            unresolvedMemberRefs: [],
            inheritedMemberRefs: [],
            rootlessKeyPathNames: [],
            nodeCount: 0,
            noa: noa,
            attributeCount: attributeCount
        )
    }

    /// The cohesion result.
    func build() -> CohesionResult {
        let attributes = orderedAttributes()
        guard Self.applicableKinds.contains(kind) else {
            return Self.notApplicable(noa: ownAttributes.uniqued().count, attributeCount: attributes.count)
        }
        var excluded: [ExcludedMember] = []
        var nodes: [MemberGroup] = []
        for group in groups {
            if let reason = exclusion(of: group) {
                excluded.append(ExcludedMember(key: group.key, reason: reason))
            } else {
                nodes.append(group)
            }
        }
        let references = nodes.map { node in
            node.records.reduce(SelfReferences()) { merged, index in
                facts[index].map { merged.merged(with: $0.references) } ?? merged
            }
        }
        let attributeSet = Set(attributes)
        // An inherited attribute the type does not shadow: `super.x`, or a use
        // that reaches the superclass, touches only one of these.
        let inheritedSet = attributeSet.subtracting(ownAttributes)
        let touches = references.map { reference in
            touched(by: reference, attributes: attributes, attributeSet: attributeSet, inheritedSet: inheritedSet)
        }
        var components = UnionFind(count: nodes.count)
        joinSharedAttributes(touches, into: &components)
        joinMemberEdges(nodes: nodes, references: references, attributes: attributeSet, into: &components)
        let everyReference = references.reduce(SelfReferences()) { $0.merged(with: $1) }
        var result = CohesionResult(
            lcom4: nil,
            nullReason: nil,
            components: [],
            isolatedMembers: [],
            excludedMembers: excluded,
            unusedAttributes: ownAttributes.filter { name in touches.allSatisfy { $0.contains(name) == false } }
                .uniqued(),
            unresolvedMemberRefs: everyReference.unresolved.sorted(),
            inheritedMemberRefs: everyReference.inherited.subtracting(inheritedSet).sorted(),
            rootlessKeyPathNames: everyReference.rootlessKeyPaths.intersection(attributeSet).sorted(),
            nodeCount: nodes.count,
            noa: ownAttributes.uniqued().count,
            attributeCount: attributes.count
        )
        addComponents(components.groups(), nodes: nodes, touches: touches, attributes: attributes, to: &result)
        result.nullReason = nullReason(attributes: attributes, nodeCount: nodes.count, counted: result.components.count)
        result.lcom4 = result.nullReason == nil ? result.components.count : nil
        return result
    }

    /// Splits the graph's components into counted ones and isolated members.
    private func addComponents(
        _ groups: [[Int]],
        nodes: [MemberGroup],
        touches: [[String]],
        attributes: [String],
        to result: inout CohesionResult
    ) {
        for members in groups {
            let touched = Set(members.flatMap { touches[$0] })
            let keys = members.map { nodes[$0].key }
            if touched.isEmpty, options.dropAttributeFreeComponents {
                result.isolatedMembers += keys
                continue
            }
            let declaring = members.map { declaringExtension(nodes[$0]) }
            result.components.append(CohesionComponent(
                members: keys,
                attributes: attributes.filter(touched.contains),
                extensions: declaring.compactMap(\.self).uniqued(),
                includesPrimaryDeclaration: declaring.contains { $0 == nil }
            ))
        }
    }

    /// A = own attributes, plus inherited ones when the option is on.
    private func orderedAttributes() -> [String] {
        let inherited = options.inheritsModuleSuperclassAttributes ? inheritedAttributes : []
        return (ownAttributes + inherited).uniqued()
    }

    /// Why a member is not a node, if it is not.
    private func exclusion(of group: MemberGroup) -> ExclusionReason? {
        switch group.role {
        case .initializer:
            return .initializer

        case .deinitializer:
            return .deinitializer

        case .observer:
            return .observer

        case .computedProperty, .function, .subscriptMember:
            break
        }
        if group.isTypeLevel {
            return .typeLevel
        }
        if Self.wholeValueWitnesses.contains(MemberCall(name: group.baseName, labels: group.labels)) {
            return .wholeValueWitness
        }
        if options.excludeDescriptionWitnesses, group.role == .computedProperty,
           Self.descriptionWitnesses.contains(group.baseName) {
            return .descriptionWitness
        }
        return nil
    }

    /// The attributes one node touches (rules 1–6). An own computed
    /// override of an inherited stored property is its own node, not a
    /// touch of the attribute it overrides.
    private func touched(
        by references: SelfReferences,
        attributes: [String],
        attributeSet: Set<String>,
        inheritedSet: Set<String>
    ) -> [String] {
        if references.wholeSelf, kind == .struct, options.wholeSelfInStructs {
            return attributes
        }
        let read = references.memberNames.union(references.keyPathMembers)
        let own = read.subtracting(ownComputed).intersection(attributeSet)
        let names = own.union(references.inherited.intersection(inheritedSet))
        return attributes.filter(names.contains)
    }

    /// Joins nodes that touch a common attribute.
    private func joinSharedAttributes(_ touches: [[String]], into components: inout UnionFind) {
        var firstToucher: [String: Int] = [:]
        for (node, names) in touches.enumerated() {
            for name in names {
                if let first = firstToucher[name] {
                    components.union(first, node)
                } else {
                    firstToucher[name] = node
                }
            }
        }
    }

    /// Joins callers to the own members they call, read or subscript.
    private func joinMemberEdges(
        nodes: [MemberGroup],
        references: [SelfReferences],
        attributes: Set<String>,
        into components: inout UnionFind
    ) {
        var byName: [String: [Int]] = [:]
        for (index, node) in nodes.enumerated() {
            byName[node.baseName, default: []].append(index)
        }
        let computed = ownComputed
        for (caller, reference) in references.enumerated() {
            for call in reference.calls {
                let named = byName[call.name] ?? []
                let exact = named.filter { nodes[$0].labels == call.labels }
                // With no label match, a stored property of that name is the
                // callee (a closure), not the methods sharing its base name.
                let fallback = attributes.contains(call.name) ? [] : named
                for target in exact.isEmpty ? fallback : exact {
                    components.union(caller, target)
                }
            }
            // A stored property read is a touch, not an edge to a method named
            // like it; a read of an own computed override is an edge.
            for name in reference.memberNames where attributes.contains(name) == false || computed.contains(name) {
                // A computed property read joins the property, not methods named like it.
                let named = byName[name] ?? []
                let properties = named.filter { nodes[$0].role == .computedProperty }
                let fallback = computed.contains(name) ? [] : named
                for target in properties.isEmpty ? fallback : properties {
                    components.union(caller, target)
                }
            }
            if reference.selfSubscript {
                for target in byName["subscript"] ?? [] {
                    components.union(caller, target)
                }
            }
        }
    }

    /// The first null reason that holds, if any.
    private func nullReason(attributes: [String], nodeCount: Int, counted: Int) -> CohesionNullReason? {
        if Self.applicableKinds.contains(kind) == false {
            return .notApplicableKind
        }
        if attributes.isEmpty {
            return .noStoredProperties
        }
        if nodeCount < Self.minimumNodes {
            return .fewerThanTwoMembers
        }
        return counted == 0 ? .noStateUse : nil
    }
}
