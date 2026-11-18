//
//  TypePass.swift
//  SwiftCodeMetrics
//
//  The type level of the module pass (Spec §9, §10.3): every merged type
//  and extension group, with sizes, WMC, cohesion and coupling, then the
//  module-wide values and the type graph.
//

/// Computes the type level from resolved records.
struct TypePass {
    /// The module's table.
    let table: SymbolTable
    /// Every record, resolved.
    let functions: [FunctionRecord]
    /// Per-record facts; nil for records outside every type.
    let facts: [RecordFacts?]
    /// Imports per file.
    let importsByFile: [String: [ImportFact]]
    /// Each file's position in the input.
    let fileOrder: [String: Int]
    /// The options.
    let options: MetricsOptions

    /// The type level.
    func run() -> TypeLevel {
        let groups = MemberGrouping.groups(functions: functions, facts: facts)
        var owned: [TypeKey: [Int]] = [:]
        for (index, fact) in facts.enumerated() {
            if let fact {
                owned[fact.owner, default: []].append(index)
            }
        }
        let keys = table.entries.keys.sorted(by: isBefore)
        let index = TypeIndex(keys: keys, table: table)
        var drafts: [TypeKey: TypeDraft] = [:]
        for key in keys {
            guard let entry = table.entries[key] else {
                continue
            }
            drafts[key] = draft(key, entry: entry, groups: groups[key] ?? [], owned: owned[key] ?? [], index: index)
        }
        let conformers = conformerCounts(drafts)
        let edges = keys.flatMap { key in
            drafts[key]?.edges.edges { targetClass($0, drafts: drafts) } ?? []
        }
        let incoming = Dictionary(grouping: edges, by: \.target).mapValues { Set($0.map(\.source)) }
        let outgoing = Dictionary(grouping: edges, by: \.source)
        let types = keys.compactMap { key in
            drafts[key].map { draft in
                result(
                    for: draft,
                    context: ResultContext(
                        drafts: drafts,
                        index: index,
                        edges: outgoing[key] ?? [],
                        incoming: incoming[key]?.count ?? 0,
                        conformers: conformers[key] ?? 0
                    )
                )
            }
        }
        return TypeLevel(
            types: types,
            edges: edges,
            cycles: StronglyConnected.cycles(in: edges),
            unresolvedExtensions: table.unresolvedExtensions.map { fact in
                extensionFact(fact, conformances: conformances(
                    fact.declaration.inherited,
                    resolver: resolver(for: fact),
                    isConditional: fact.declaration.isConstrained
                ))
            }
        )
    }

    /// The number of non-protocol types conforming to each protocol,
    /// directly or through refinement (Spec §9.5).
    private func conformerCounts(_ drafts: [TypeKey: TypeDraft]) -> [TypeKey: Int] {
        var conformers: [TypeKey: Int] = [:]
        for draft in drafts.values where draft.entry.kind != .protocol && draft.entry.kind != .extensionGroup {
            for target in refinedProtocols(of: draft.conformanceTargets, drafts: drafts) {
                conformers[target, default: 0] += 1
            }
        }
        return conformers
    }

    /// Source order: file, then the first declaration's offset.
    private func isBefore(_ first: TypeKey, _ second: TypeKey) -> Bool {
        let left = position(of: first)
        let right = position(of: second)
        if left.file != right.file {
            return left.file < right.file
        }
        if left.offset != right.offset {
            return left.offset < right.offset
        }
        return first.description < second.description
    }

    /// Where a type is first declared.
    private func position(of key: TypeKey) -> (file: Int, offset: Int) {
        let entry = table.entries[key]
        if let primary = entry?.declarations.first {
            return (fileOrder[primary.file] ?? Int.max, primary.declaration.range.start)
        }
        if let first = entry?.extensionFacts.first {
            return (fileOrder[first.file] ?? Int.max, first.declaration.range.start)
        }
        return (Int.max, 0)
    }

    /// One type's draft: declarations resolved, references grouped.
    private func draft(
        _ key: TypeKey,
        entry: TypeEntry,
        groups: [MemberGroup],
        owned: [Int],
        index: TypeIndex
    ) -> TypeDraft {
        var edges = TypeEdges(owner: key, family: index.familyRoot(of: key))
        var declarationReferences: [TypeReference] = []
        var conformances: [ConformanceFact] = []
        var extensions: [ExtensionFact] = []
        for fact in entry.declarations {
            let clause = clauseResolver(for: fact)
            let site = DeclarationSite(owner: entry, isExtension: false, clauseResolver: clause)
            let resolver = resolver(for: fact)
            declarationReferences += add(fact.declaration, at: site, resolver: resolver, index: index, into: &edges)
            let inherited = fact.declaration.inherited
            conformances += self.conformances(
                entry.kind == .class ? withoutSuperclass(inherited, resolver: clause) : inherited,
                resolver: clause,
                isConditional: false
            )
        }
        for fact in entry.extensionFacts {
            let resolver = resolver(for: fact)
            let site = DeclarationSite(owner: entry, isExtension: true, clauseResolver: resolver)
            declarationReferences += add(fact.declaration, at: site, resolver: resolver, index: index, into: &edges)
            // `extension IntBox: P` where `IntBox = Box<Int>` is constrained too.
            let isBoundAlias = table.reachesBoundGeneric(fact.extended, from: resolver.context)
            let own = self.conformances(
                fact.declaration.inherited,
                resolver: resolver,
                isConditional: fact.declaration.isConstrained || isBoundAlias
            )
            conformances += own
            extensions.append(extensionFact(fact, conformances: own))
        }
        addRecordReferences(owned, groups: groups, index: index, into: &edges)
        let (superclass, possibleSuperclass) = superclassFacts(of: key, entry: entry)
        return TypeDraft(
            key: key,
            entry: entry,
            groups: groups,
            declarationReferences: declarationReferences,
            edges: edges,
            conformances: conformances.uniqued(),
            extensions: extensions,
            superclass: superclass,
            possibleSuperclass: possibleSuperclass
        )
    }

    /// The in-module superclass, or else the first inherited name when it
    /// could be a superclass the module does not declare (Spec §9.1).
    private func superclassFacts(of key: TypeKey, entry: TypeEntry) -> (TypeKey?, String?) {
        let primaryInherited = entry.declarations.first?.declaration.inherited.first
        let primaryResolver = entry.declarations.first.map(clauseResolver(for:))
        let isPossible = entry.kind == .class
            && primaryResolver.map { isPossibleSuperclass(primaryInherited, resolver: $0) } == true
        let superclass = table.superclasses(of: key).first
        return (superclass, isPossible && superclass == nil ? primaryInherited?.name : nil)
    }

    /// Resolves a declaration's type names into `edges`, returning the references.
    private func add(
        _ declaration: TypeDeclarationFacts,
        at site: DeclarationSite,
        resolver: FunctionResolver,
        index: TypeIndex,
        into edges: inout TypeEdges
    ) -> [TypeReference] {
        let owner = site.owner
        var entryKinds: [Int: EdgeKind] = [:]
        var references: [TypeReference] = []
        for name in declaration.typeNames {
            // Inheritance-clause names resolve outside the type's body.
            let nameResolver = name.inheritanceEntry == nil ? resolver : site.clauseResolver
            guard let reference = nameResolver.typeReference(for: name) else {
                // `struct Client: Services` where `Services = Fetching & Caching`;
                // elsewhere, `let deps: Services` names each member with its own kind.
                let members = name.edgeKind == .inheritance
                    ? compositionMembers(of: name, resolver: nameResolver, owner: owner)
                    : nameResolver.expandedReferences(for: name)
                for member in members {
                    edges.add(
                        member,
                        kind: member.edgeKind,
                        isWeakOrUnowned: name.isWeakOrUnowned,
                        familyOf: index.familyRoot(of:)
                    )
                    references.append(member)
                }
                continue
            }
            var kind = name.edgeKind
            if kind == .inheritance {
                // The entry's first name decides the kind of its generic arguments too.
                kind = name.inheritanceEntry.flatMap { entryKinds[$0] }
                    ?? inheritanceKind(of: reference, site: site, entry: name.inheritanceEntry ?? 0)
                if let entry = name.inheritanceEntry, entryKinds[entry] == nil {
                    entryKinds[entry] = kind
                }
            }
            var tagged = reference
            tagged.edgeKind = kind
            edges.add(tagged, kind: kind, isWeakOrUnowned: name.isWeakOrUnowned, familyOf: index.familyRoot(of:))
            references.append(tagged)
        }
        return references
    }

    /// The kind an inheritance-clause entry gives: refinement or conformance
    /// for a protocol target, inheritance for anything else.
    private func inheritanceKind(of reference: TypeReference, site: DeclarationSite, entry: Int) -> EdgeKind {
        let owner = site.owner
        if let target = reference.target {
            guard table.entries[target]?.kind == .protocol else {
                // `protocol Themed: BaseView` constrains to a class: inheritance.
                return .inheritance
            }
            return owner.kind == .protocol ? .refinement : .conformance
        }
        // Otherwise a protocol inherits protocols: `protocol Store: Collection<Item>`.
        if owner.kind == .protocol {
            return .refinement
        }
        let lastName = reference.spelling.split(separator: ".").last.map(String.init) ?? reference.spelling
        let isPlatformProtocol = reference.bucket == .platform
            && (table.platform.protocols.contains(reference.spelling) || table.platform.protocols.contains(lastName))
        // Only a class's first entry can be a superclass; an extension's entries are protocols.
        let canBeSuperclass = owner.kind == .class && site.isExtension == false && entry == 0
        return isPlatformProtocol || canBeSuperclass == false ? .conformance : .inheritance
    }

    /// How a `ce` target is classified (Spec §9.4).
    private func targetClass(_ target: TypeKey, drafts: [TypeKey: TypeDraft]) -> TargetClass {
        guard let draft = drafts[target] else {
            return .concrete
        }
        if draft.entry.kind == .protocol {
            return .protocol
        }
        if table.byPath[["View"]]?.isEmpty != false, conformsToView(draft, drafts: drafts) {
            return .view
        }
        if draft.entry.kind == .enum, draft.caseNames.isEmpty, draft.hasInstanceMembers == false {
            return .namespace
        }
        return .concrete
    }

    /// Whether a type conforms to SwiftUI's `View`, directly or through module protocols.
    private func conformsToView(_ draft: TypeDraft, drafts: [TypeKey: TypeDraft]) -> Bool {
        let viewNames: Set<String> = ["SwiftUI.View", "SwiftUI::View", "View"]
        let refined = refinedProtocols(of: draft.conformanceTargets, drafts: drafts).compactMap { drafts[$0] }
        let protocols = [draft] + refined
        return protocols.contains { candidate in
            candidate.conformances.contains { viewNames.contains($0.name) && $0.target == nil }
        }
    }

    /// The module protocols `targets` name, and every protocol they refine.
    func refinedProtocols(of targets: Set<TypeKey>, drafts: [TypeKey: TypeDraft]) -> Set<TypeKey> {
        var seen: Set<TypeKey> = []
        var pending = Array(targets)
        while let next = pending.popLast() {
            guard seen.insert(next).inserted else {
                continue
            }
            pending += drafts[next]?.conformanceTargets ?? []
        }
        return seen
    }
}
