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

    /// A resolver for a type's inheritance clause, which Swift looks up
    /// outside the type's body: its generic parameters are visible, its
    /// nested types are not, so `class Outer: Base` with a nested `Outer.Base`
    /// inherits the top-level Base. A top-level local type keeps its own
    /// position, for the function around it.
    func clauseResolver(for fact: TypeFact) -> FunctionResolver {
        guard fact.path.count > 1 || fact.localTo == nil else {
            return resolver(for: fact)
        }
        let parentPath = Array(fact.path.dropLast())
        return resolver(
            context: FunctionContext(
                typePath: parentPath,
                extensionPathLength: min(fact.extensionPathLength, parentPath.count),
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
