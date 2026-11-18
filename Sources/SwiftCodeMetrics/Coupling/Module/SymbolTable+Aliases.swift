//
//  SymbolTable+Aliases.swift
//  SwiftCodeMetrics
//
//  Which module typealias a name reaches (Spec §7.3), for closure
//  parameters, compositions and bound generic extensions.
//

extension SymbolTable {
    /// The module typealias a name reaches by the §7.3 order, or nil when it
    /// reaches a type, a generic parameter or nothing the module declares.
    func aliasTarget(for spelled: SpelledType, from context: ResolutionContext) -> TypealiasFact? {
        if let (module, rest) = moduleQualified(spelled, from: context) {
            guard module == self.module else {
                return nil
            }
            let unqualified = SpelledType(components: rest, moduleSelector: nil)
            return aliasTarget(for: unqualified, from: topLevelContext(file: context.file))
        }
        let components = spelled.components
        guard let name = components.last, let root = components.first,
              context.genericParameters.contains(root) == false else {
            return nil
        }
        guard components.count == 1 else {
            return memberAlias(components, from: context)
        }
        // The §7.3 order: local types' chain, function-local types, the
        // outer chain, then module top level.
        let localChain = context.chain.prefix { $0.localTo != nil }
        if let found = chainAlias(name, in: localChain, from: context.file) {
            return found
        }
        if context.localOwners.contains(where: { locals[$0]?[[name]] != nil }) {
            return nil
        }
        if let found = chainAlias(name, in: context.chain.dropFirst(localChain.count), from: context.file) {
            return found
        }
        if visible(byPath[[name]] ?? [], from: context.file).isEmpty == false {
            return nil
        }
        let aliases = visibleAliases(name, from: context.file)
        // `#if` variants with different targets name no one alias.
        guard let first = aliases.first,
              aliases.allSatisfy({ $0.target == first.target && $0.closure == first.closure }) else {
            return nil
        }
        return first
    }

    /// What the first chain type, or superclass, with a nested type or member
    /// typealias named `name` gives: `.some(alias)`, or `.some(nil)` when a
    /// nested type shadows it or its variants conflict. Nil when none has one.
    private func chainAlias(
        _ name: String,
        in chain: ArraySlice<TypeKey>,
        from file: String
    ) -> TypealiasFact?? {
        for type in chain {
            for candidate in [type] + superclasses(of: type) {
                if nestedTypes(named: name, of: candidate, from: file).isEmpty == false {
                    return .some(nil)
                }
                if let found = entries[candidate]?.typealiases[name] {
                    let isConflicting = entries[candidate]?.conflictingAliases.contains(name) == true
                    return .some(isConflicting ? nil : found)
                }
            }
        }
        return nil
    }

    /// `Module.rest` or `Module::rest`, when the name is module-qualified.
    private func moduleQualified(_ spelled: SpelledType, from context: ResolutionContext) -> (String, [String])? {
        if let selector = spelled.moduleSelector {
            return (selector, spelled.components)
        }
        guard spelled.components.count > 1, let root = spelled.components.first, context.knownModules.contains(root),
              visible(byPath[[root]] ?? [], from: context.file).isEmpty else {
            return nil
        }
        return (root, Array(spelled.components.dropFirst()))
    }

    /// `A.Alias`: a member typealias of the type `A` names, unless a nested type shadows it.
    private func memberAlias(_ components: [String], from context: ResolutionContext) -> TypealiasFact? {
        guard let name = components.last else {
            return nil
        }
        let ownerPath = Array(components.dropLast())
        let owner = resolve(SpelledType(components: ownerPath, moduleSelector: nil), from: context)
        // `String.Transform`: an alias in an extension group.
        guard let key = owner.moduleKey ?? groupKey(for: ownerPath, resolution: owner),
              nestedTypes(named: name, of: key, from: context.file).isEmpty,
              entries[key]?.conflictingAliases.contains(name) == false else {
            return nil
        }
        return entries[key]?.typealiases[name]
    }

    /// The nested types named `name` of `type`, local or not.
    private func nestedTypes(named name: String, of type: TypeKey, from file: String) -> [TypeKey] {
        if let owner = type.localTo {
            return locals[owner]?[type.path + [name]].map { [$0] } ?? []
        }
        return visible(byPath[type.path + [name]] ?? [], from: file)
    }
}
