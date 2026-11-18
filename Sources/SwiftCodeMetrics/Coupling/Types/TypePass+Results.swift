//
//  TypePass+Results.swift
//  SwiftCodeMetrics
//
//  Assembling one TypeResult: sizes, WMC, protocol facts, cohesion and the coupling summary (Spec §9.1–9.5).
//

extension TypePass {
    /// Attached macros SwiftProjectLint and SwiftStats know (Spec §9.1).
    static let knownMacroAttributes: Set<String> = [
        "CasePathable", "DependencyClient", "Model", "Observable", "ObservableState", "Reducer"
    ]

    /// A protocol's requirements, `#if` variants merged.
    private static func requirements(of entry: TypeEntry) -> [MemberFact] {
        var seen: Set<MemberFact> = []
        return entry.declarations.flatMap(\.members).filter { member in
            member.kind != .enumCase && seen.insert(member).inserted
        }
    }

    /// Whether a default implementation matches a requirement by base name and labels.
    private static func matches(_ group: MemberGroup, _ requirement: MemberFact) -> Bool {
        switch group.role {
        case .function:
            // Operators have no argument labels: `lhs:` and `left:` both match.
            let isOperator = group.baseName.first.map { $0.isLetter || $0 == "_" } == false
            return requirement.kind == .function && requirement.name == group.baseName
                && (isOperator
                    ? requirement.labels.count == group.labels.count
                    : requirement.labels.map(SyntaxFacts.bare) == group.labels)

        case .computedProperty:
            return requirement.kind.isProperty && requirement.name == group.baseName

        case .subscriptMember:
            return requirement.kind == .subscriptMember && requirement.labels == group.labels

        case .initializer:
            return requirement.kind == .initializer && requirement.labels == group.labels

        case .deinitializer, .observer:
            return false
        }
    }

    /// The finished result for one type.
    func result(for draft: TypeDraft, context: ResultContext) -> TypeResult {
        let entry = draft.entry
        let isProtocol = entry.kind == .protocol
        let ownAttributes = entry.declarations.flatMap(\.declaration.storedProperties).map(\.name).uniqued()
        let inheritedAttributes = table.superclasses(of: draft.key).flatMap { parent in
            table.entries[parent]?.declarations.flatMap(\.declaration.storedProperties).map(\.name) ?? []
        }
        let cohesion = CohesionBuilder(
            kind: entry.kind,
            ownAttributes: ownAttributes,
            inheritedAttributes: inheritedAttributes,
            groups: draft.groups.filter(\.isMember),
            facts: facts,
            options: options.cohesion
        ) { declaringExtension(of: $0, in: draft) }
            .build()
        return TypeResult(
            key: draft.key,
            kind: entry.kind,
            sizes: sizes(of: draft),
            wmc: wmc(of: draft.groups, isDefaults: isProtocol),
            cohesion: cohesion,
            coupling: summary(of: draft, context: context),
            declarationTypeReferences: draft.declarationReferences,
            unresolvedTypeRefs: draft.edges.unresolvedNames.sorted(),
            ambiguousTypeRefs: draft.edges.ambiguousNames.sorted(),
            protocolFacts: isProtocol ? protocolFacts(of: draft, conformers: context.conformers) : nil,
            extensions: draft.extensions,
            conformances: draft.conformances,
            superclass: draft.superclass,
            possibleSuperclass: draft.possibleSuperclass,
            customAttributes: entry.declarations.flatMap(\.declaration.customAttributes).uniqued(),
            hasKnownAttachedMacro: hasKnownAttachedMacro(entry)
        )
    }

    /// Member counts (Spec §9.1).
    private func sizes(of draft: TypeDraft) -> TypeSizes {
        let stored = draft.entry.declarations.flatMap(\.declaration.storedProperties)
        var seen: Set<String> = []
        let properties = stored.filter { seen.insert($0.name).inserted }
        let caseCount = draft.entry.kind == .enum ? draft.caseNames.count : nil
        guard draft.entry.kind != .protocol else {
            let requirements = Self.requirements(of: draft.entry)
            let statics = requirements.filter(\.isTypeLevel).count
            return TypeSizes(
                nom: requirements.count,
                instanceMembers: requirements.count - statics,
                staticMembers: statics,
                initialisers: requirements.filter { $0.kind == .initializer }.count,
                computedProperties: requirements.filter(\.kind.isProperty).count,
                subscripts: requirements.filter { $0.kind == .subscriptMember }.count,
                noa: 0,
                storedProperties: [],
                caseCount: nil
            )
        }
        let members = draft.groups.filter { $0.isMember && $0.role != .observer }
        let statics = members.filter { $0.isTypeLevel && $0.role != .initializer && $0.role != .deinitializer }.count
        return TypeSizes(
            nom: members.count,
            instanceMembers: members.count - statics,
            staticMembers: statics,
            initialisers: members.filter { $0.role == .initializer }.count,
            computedProperties: members.filter { $0.role == .computedProperty }.count,
            subscripts: members.filter { $0.role == .subscriptMember }.count,
            noa: properties.count,
            storedProperties: properties,
            caseCount: caseCount
        )
    }

    /// The sum over members of each member's largest `#if` variant (Spec §9.2).
    private func wmc(of groups: [MemberGroup], isDefaults: Bool) -> WMC {
        var cognitive = 0
        var decisions = 0
        for group in groups {
            var byVariant: [String: (cognitive: Int, decisions: Int)] = [:]
            var variantOfRoot: [Int: String] = [:]
            for (condition, roots) in group.variants {
                for root in roots {
                    variantOfRoot[root] = condition
                }
            }
            for index in group.records {
                let root = MemberGrouping.root(of: index, functions: functions, facts: facts)
                let condition = variantOfRoot[root] ?? ""
                let scores = functions[index].complexity
                byVariant[condition, default: (0, 0)].cognitive += scores.cognitive
                byVariant[condition, default: (0, 0)].decisions += scores.decisionCount
            }
            cognitive += byVariant.values.map(\.cognitive).max() ?? 0
            decisions += byVariant.values.map(\.decisions).max() ?? 0
        }
        return WMC(cognitive: cognitive, decisions: decisions, isDefaults: isDefaults)
    }

    /// Requirement and default counts (Spec §9.1, §9.5).
    private func protocolFacts(of draft: TypeDraft, conformers: Int) -> ProtocolFacts {
        let requirements = Self.requirements(of: draft.entry)
        let associated = Set(draft.entry.declarations.flatMap(\.associatedTypes))
        let defaults = draft.groups.filter { $0.isMember && $0.role != .observer }
        let matching = defaults.filter { group in
            requirements.contains { Self.matches(group, $0) }
        }
        return ProtocolFacts(
            requirementCount: requirements.count + associated.count,
            defaultImplementationCount: defaults.count,
            defaultsForRequirements: matching.count,
            extensionOnlyMembers: defaults.count - matching.count,
            conformerCount: conformers
        )
    }

    /// The coupling summary (Spec §9.4, §9.5).
    private func summary(of draft: TypeDraft, context: ResultContext) -> TypeCouplingSummary {
        let own = context.edges
        let classes = own.compactMap(\.targetClass)
        let index = context.index
        let subtree = index.subtrees[draft.key] ?? [draft.key]
        let familyTargets = Set(subtree.flatMap { nested in
            context.drafts[nested]?.edges.kinds.keys.map(index.familyRoot(of:)) ?? []
        }).subtracting([index.familyRoot(of: draft.key)])
        return TypeCouplingSummary(
            ceTotal: own.count,
            ceConcrete: classes.filter { $0 == .concrete }.count,
            ceProtocol: classes.filter { $0 == .protocol }.count,
            ceView: classes.filter { $0 == .view }.count,
            ceNamespace: classes.filter { $0 == .namespace }.count,
            ceFamily: familyTargets.count,
            internalRefs: draft.edges.internalTargets.count,
            externalNameCount: draft.edges.externalNames.count,
            platformNameCount: draft.edges.platformNames.count,
            caWithinModule: context.incoming,
            unresolvedTypeRefCount: draft.edges.unresolvedNames.count,
            ambiguousTypeRefCount: draft.edges.ambiguousNames.count
        )
    }

    /// The extension a member is declared in, by its first record's position.
    private func declaringExtension(of group: MemberGroup, in draft: TypeDraft) -> ExtensionFact? {
        let record = functions[group.firstRecord]
        guard let file = facts[group.firstRecord]?.file else {
            return nil
        }
        return draft.extensions.first { fact in
            fact.file == file && fact.range.start <= record.range.start && record.range.end <= fact.range.end
        }
    }

    /// Whether the type or a member carries a known or module-declared attached macro.
    private func hasKnownAttachedMacro(_ entry: TypeEntry) -> Bool {
        let names = entry.declarations.flatMap(\.declaration.attachedAttributeNames)
            + entry.extensionFacts.flatMap(\.declaration.attachedAttributeNames)
        return names.contains { written in
            let bare = written.split(separator: "<").first.map(String.init) ?? written
            let last = bare.split(separator: ".").last.map(String.init) ?? bare
            return Self.knownMacroAttributes.contains(last) || table.macroNames.contains(last)
        }
    }
}
