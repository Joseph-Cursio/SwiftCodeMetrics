//
//  TypePass+Declarations.swift
//  SwiftCodeMetrics
//
//  Resolving a type's or extension's declaration-level names: synthetic
//  resolvers at the declaration's position, conformances and the possible
//  superclass (Spec §7.3, §9.1).
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

    /// Conformances from an inheritance clause; a class's first entry is
    /// skipped when it is its superclass or possible superclass (Spec §9.1).
    func conformances(
        _ inherited: [RawInherited],
        resolver: FunctionResolver,
        isConditional: Bool,
        skipsFirst: Bool
    ) -> [ConformanceFact] {
        inherited.dropFirst(skipsFirst ? 1 : 0).flatMap { entry -> [ConformanceFact] in
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
    /// inheritance-clause typealias composition stands for.
    func compositionMembers(of name: RawTypeName, resolver: FunctionResolver, owner: TypeEntry) -> [TypeReference] {
        table.compositionLeaves(of: name.type, from: resolver.context).compactMap { leaf in
            guard case .module(let key) = table.resolve(leaf.type, from: leaf.position),
                  let kind = table.entries[key]?.kind else {
                return nil
            }
            let edgeKind: EdgeKind
            switch kind {
            case .protocol:
                edgeKind = owner.kind == .protocol ? .refinement : .conformance

            case .class where owner.kind == .class || owner.kind == .protocol:
                // A superclass, or a protocol's class constraint.
                edgeKind = .inheritance

            case .actor, .class, .enum, .extensionGroup, .struct:
                return nil
            }
            return TypeReference(
                spelling: leaf.type.spelling,
                edgeKind: edgeKind,
                utf8Offset: name.offset,
                bucket: .module,
                target: key,
                resolution: .exact
            )
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
}
