//
//  TypePass+Declarations.swift
//  SwiftCodeMetrics
//
//  Resolving a type's or extension's declaration-level names: synthetic
//  resolvers at the declaration's position, conformances and the possible
//  superclass (Spec §7.3, §9.1), and the edge kinds of owned records.
//

extension TypePass {
    /// A resolver at a type declaration's own position.
    func resolver(for fact: TypeFact) -> FunctionResolver {
        resolver(
            context: FunctionContext(
                typePath: fact.path,
                extensionPathLength: fact.extensionPathLength,
                localOwner: fact.localTo,
                enclosingRecords: fact.localTo.map { [$0] } ?? [],
                genericParameters: fact.genericParameters + fact.associatedTypes,
                isTypeLevel: false,
                file: fact.file
            ),
            typeNames: fact.declaration.typeNames
        )
    }

    /// A resolver for a type's inheritance clause, which Swift looks up
    /// outside the type's body: its generic parameters are visible, its
    /// nested types and member typealiases are not, so `class Outer: Base`
    /// with a nested `Outer.Base` inherits the top-level Base. A top-level
    /// local type's clause resolves where the function around it does.
    func clauseResolver(for fact: TypeFact) -> FunctionResolver {
        let isTopLevelLocal = fact.path.count == 1 && fact.localTo != nil
        let parentPath = isTopLevelLocal ? fact.enclosingTypePath : Array(fact.path.dropLast())
        return resolver(
            context: FunctionContext(
                typePath: parentPath,
                extensionPathLength: isTopLevelLocal ? 0 : min(fact.extensionPathLength, parentPath.count),
                localOwner: isTopLevelLocal ? fact.enclosingLocalOwner : fact.localTo,
                enclosingRecords: fact.localTo.map { [$0] } ?? [],
                genericParameters: fact.genericParameters + fact.associatedTypes,
                isTypeLevel: false,
                file: fact.file
            ),
            typeNames: fact.declaration.typeNames
        )
    }

    /// A resolver inside an extension.
    func resolver(for fact: ExtensionDeclFact) -> FunctionResolver {
        resolver(
            context: FunctionContext(
                typePath: fact.extended.extensionPath(in: table.module),
                extensionPathLength: fact.extended.extensionPath(in: table.module).count,
                localOwner: nil,
                enclosingRecords: [],
                genericParameters: [],
                isTypeLevel: false,
                file: fact.file
            ),
            typeNames: fact.declaration.typeNames
        )
    }

    /// A resolver for an extension's inheritance clause, which Swift looks
    /// up where the extension is written: the extended type's nested types
    /// and member typealiases are not visible, so `extension Outer: Delegate`
    /// with a nested `Outer.Delegate` conforms to the top-level Delegate.
    func clauseResolver(for fact: ExtensionDeclFact) -> FunctionResolver {
        var parentPath = Array(fact.extended.extensionPath(in: table.module).dropLast())
        if SpelledType.selector(of: parentPath) != nil, parentPath.count == 1 {
            parentPath = []
        }
        return resolver(
            context: FunctionContext(
                typePath: parentPath,
                extensionPathLength: parentPath.count,
                localOwner: nil,
                enclosingRecords: [],
                genericParameters: [],
                isTypeLevel: false,
                file: fact.file
            ),
            typeNames: fact.declaration.typeNames
        )
    }

    /// A resolver for declaration-level names in `context`.
    private func resolver(context: FunctionContext, typeNames: [RawTypeName]) -> FunctionResolver {
        let raw = RawFunctionReferences(
            context: context,
            calls: [],
            names: [],
            memberReads: [],
            typeNames: typeNames,
            macroExpansionCount: 0,
            carriesParameters: false,
            parameters: []
        )
        return FunctionResolver(table: table, raw: raw, imports: importsByFile[context.file] ?? [], options: options)
    }

    /// Conformances from an inheritance clause; a class's superclass is
    /// taken out first, by withoutSuperclass (Spec §9.1).
    func conformances(
        _ inherited: [RawInherited],
        resolver: FunctionResolver,
        isConditional: Bool
    ) -> [ConformanceFact] {
        inherited.flatMap { entry -> [ConformanceFact] in
            guard let type = entry.type else {
                return [ConformanceFact(name: entry.name, target: nil, isConditional: isConditional)]
            }
            if let key = protocolKey(type, from: resolver.context) {
                return [ConformanceFact(name: entry.name, target: key, isConditional: isConditional)]
            }
            // A typealias composition expands into its protocols (Spec §9.5); a
            // module class in it is the superclass, not a conformance.
            let leaves = table.compositionLeaves(of: type, from: resolver.context)
            if leaves.isEmpty == false {
                return leaves.compactMap { leaf in
                    if case .module(let key) = table.resolve(leaf.type, from: leaf.position),
                       table.entries[key]?.kind == .class {
                        return nil
                    }
                    return ConformanceFact(
                        name: leaf.type.spelling,
                        target: protocolKey(leaf.type, from: leaf.position),
                        isConditional: isConditional
                    )
                }
            }
            return [ConformanceFact(name: entry.name, target: nil, isConditional: isConditional)]
        }
    }

    /// The module protocol a written type names, if it names one.
    private func protocolKey(_ type: SpelledType, from context: ResolutionContext) -> TypeKey? {
        guard case .module(let key) = table.resolve(type, from: context), table.entries[key]?.kind == .protocol else {
            return nil
        }
        return key
    }

    /// The conformance, refinement or inheritance references an
    /// inheritance-clause typealias composition stands for, every member
    /// counted as if the composition were written: `Fetching & Hashable`
    /// names the module protocol and the platform one.
    func compositionMembers(of name: RawTypeName, resolver: FunctionResolver, owner: TypeEntry) -> [TypeReference] {
        let protocolKind: EdgeKind = owner.kind == .protocol ? .refinement : .conformance
        return resolver.expandedReferences(for: name).compactMap { reference in
            var tagged = reference
            guard let key = reference.target else {
                tagged.edgeKind = protocolKind
                return tagged
            }
            switch table.entries[key]?.kind {
            case .protocol:
                tagged.edgeKind = protocolKind

            case .class where owner.kind == .class || owner.kind == .protocol:
                // A superclass, or a protocol's class constraint.
                tagged.edgeKind = .inheritance

            case .actor, .class, .enum, .extensionGroup, .struct, nil:
                return nil
            }
            return tagged
        }
    }

    /// A class's inherited names without its superclass: the first name
    /// when it can be one, or the module class anywhere in a first-entry
    /// composition, so `class Card: Themed & Base` conforms to Themed.
    func withoutSuperclass(_ inherited: [RawInherited], resolver: FunctionResolver) -> [RawInherited] {
        guard inherited.filter({ $0.entry == 0 }).count > 1 else {
            return isPossibleSuperclass(inherited.first, resolver: resolver) ? Array(inherited.dropFirst()) : inherited
        }
        return inherited.filter { name in
            guard name.entry == 0, let type = name.type else {
                return true
            }
            return table.moduleClass(type, from: resolver.context) == nil
        }
    }

    /// Whether a class's first inherited name can be its superclass: it is
    /// not a known protocol (a module protocol or a platform protocol), §7.3.
    func isPossibleSuperclass(_ first: RawInherited?, resolver: FunctionResolver) -> Bool {
        guard let first, let type = first.type else {
            return false
        }
        // A composition alias is expanded instead: its protocols are
        // conformances, and a module class in it is the superclass.
        if table.compositionLeaves(of: type, from: resolver.context).isEmpty == false {
            return false
        }
        switch table.resolve(type, from: resolver.context) {
        case .module(let key):
            return table.entries[key]?.kind != .protocol

        case .platform(let name):
            return table.platform.protocols.contains(name) == false
                && table.platform.protocols.contains(type.components.last ?? name) == false

        case .ambiguous, .external, .genericParameter, .opaqueAlias, .unresolved:
            return true
        }
    }

    /// The public fact for an extension.
    func extensionFact(_ fact: ExtensionDeclFact, conformances: [ConformanceFact]) -> ExtensionFact {
        ExtensionFact(
            file: fact.file,
            range: fact.declaration.range,
            extendedType: fact.declaration.writtenName,
            conformances: conformances.isEmpty
                ? fact.declaration.inherited.map { ConformanceFact(name: $0.name, target: nil, isConditional: false) }
                : conformances,
            whereClause: fact.declaration.whereClause
        )
    }

    /// Adds the type references of the records a type owns. Only a member's
    /// own head is a signature; a nested function's or a local accessor's
    /// head counts like any body (Spec §2.1, §9.4).
    func addRecordReferences(
        _ owned: [Int],
        groups: [MemberGroup],
        index: TypeIndex,
        into edges: inout TypeEdges
    ) {
        let memberRecords = Set(groups.filter(\.isMember).flatMap { $0.variants.values.joined() })
        for record in owned {
            for reference in functions[record].typeReferences {
                let isNestedHead = reference.edgeKind == .signature && memberRecords.contains(record) == false
                let kind = isNestedHead ? EdgeKind.body : reference.edgeKind
                edges.add(reference, kind: kind, isWeakOrUnowned: false, familyOf: index.familyRoot(of:))
            }
        }
    }
}
