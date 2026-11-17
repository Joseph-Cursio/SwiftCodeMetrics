//
//  SymbolTable+Resolution.swift
//  SwiftCodeMetrics
//
//  Type resolution against the module symbol table (Spec §7.3), with
//  typealias expansion and `Module.Name` qualification.
//

extension SymbolTable {
    /// Resolves a type name by Spec §7.3's order.
    func resolve(_ spelled: SpelledType, from context: ResolutionContext) -> TypeResolution {
        var visiting: Set<String> = []
        return resolve(spelled, from: context, visiting: &visiting)
    }

    /// Resolution with a typealias cycle guard.
    private func resolve(
        _ spelled: SpelledType,
        from context: ResolutionContext,
        visiting: inout Set<String>
    ) -> TypeResolution {
        let components = spelled.components
        guard let root = components.first else {
            return .unresolved
        }
        if let selector = spelled.moduleSelector {
            return resolveQualified(module: selector, rest: components, context: context, visiting: &visiting)
        }
        if components.count > 1, context.knownModules.contains(root),
           visible(byPath[[root]] ?? [], from: context.file).isEmpty {
            return resolveQualified(
                module: root,
                rest: Array(components.dropFirst()),
                context: context,
                visiting: &visiting
            )
        }
        if context.genericParameters.contains(root) {
            return .genericParameter
        }
        if root == "Self" {
            guard let current = context.chain.first else {
                return .genericParameter
            }
            // `Self` in an extension of a platform type is that type, not a module type.
            if entries[current]?.kind == .extensionGroup {
                return fallback(current.path + components.dropFirst(), context: context)
            }
            return descend(
                from: .module(current),
                through: components.dropFirst(),
                context: context,
                visiting: &visiting
            )
        }
        guard let first = resolveRoot(root, context: context, visiting: &visiting) else {
            // A type nested in an extension of a platform or external type keeps
            // its written path: `String.Limits`.
            if components.count > 1, let exact = visible(byPath[components] ?? [], from: context.file).first {
                return .module(exact)
            }
            return fallback(components, context: context)
        }
        return descend(from: first, through: components.dropFirst(), context: context, visiting: &visiting)
    }

    /// A simple name through the nesting chain, local types, then module top level.
    private func resolveRoot(
        _ name: String,
        context: ResolutionContext,
        visiting: inout Set<String>
    ) -> TypeResolution? {
        // Local types and their nested types are nearer than the types around
        // the function that declares them.
        let localChain = context.chain.prefix { $0.localTo != nil }
        if let found = chainType(name, in: localChain, context: context, visiting: &visiting) {
            return found
        }
        for owner in context.localOwners {
            if let local = locals[owner]?[[name]] {
                return .module(local)
            }
        }
        let outerChain = context.chain.dropFirst(localChain.count)
        if let found = chainType(name, in: outerChain, context: context, visiting: &visiting) {
            return found
        }
        let tops = visible(byPath[[name]] ?? [], from: context.file)
        if let only = tops.first {
            return tops.count == 1 ? .module(only) : .ambiguous
        }
        if let alias = visibleAliases(name, from: context.file).first {
            return expand(alias, context: context, visiting: &visiting)
        }
        return nil
    }

    /// A nested type or member typealias of a chain type or its superclasses.
    private func chainType(
        _ name: String,
        in chain: ArraySlice<TypeKey>,
        context: ResolutionContext,
        visiting: inout Set<String>
    ) -> TypeResolution? {
        for type in chain {
            for candidate in [type] + superclasses(of: type) {
                if let found = memberType(name, of: candidate, context: context, visiting: &visiting) {
                    return found
                }
            }
        }
        return nil
    }

    /// A nested type or member typealias of `type`.
    private func memberType(
        _ name: String,
        of type: TypeKey,
        context: ResolutionContext,
        visiting: inout Set<String>
    ) -> TypeResolution? {
        let nested: [TypeKey]
        if let owner = type.localTo {
            nested = locals[owner]?[type.path + [name]].map { [$0] } ?? []
        } else {
            nested = visible(byPath[type.path + [name]] ?? [], from: context.file)
        }
        if let only = nested.first {
            return nested.count == 1 ? .module(only) : .ambiguous
        }
        guard let alias = entries[type]?.typealiases[name] else {
            return nil
        }
        return expand(alias, context: context, visiting: &visiting)
    }

    /// Follows the remaining components of a qualified name.
    private func descend(
        from start: TypeResolution,
        through rest: ArraySlice<String>,
        context: ResolutionContext,
        visiting: inout Set<String>
    ) -> TypeResolution {
        var current = start
        for component in rest {
            switch current {
            case .module(let key):
                current = memberType(component, of: key, context: context, visiting: &visiting) ?? .unresolved

            case .platform(let name):
                current = .platform(name + "." + component)

            case .external(let name):
                current = .external(name + "." + component)

            case .ambiguous, .genericParameter, .opaqueAlias, .unresolved:
                return current
            }
        }
        return current
    }

    /// Expands a typealias one level, from its own position.
    private func expand(
        _ alias: TypealiasFact,
        context: ResolutionContext,
        visiting: inout Set<String>
    ) -> TypeResolution {
        let identity = alias.file + "|" + alias.typePath.joined(separator: ".") + "|" + alias.name
        guard let target = alias.target, visiting.insert(identity).inserted else {
            return .opaqueAlias
        }
        defer { visiting.remove(identity) }
        return resolve(target, from: position(of: alias, from: context), visiting: &visiting)
    }

    /// The context a typealias's target resolves from: its own position, with
    /// the generic parameters of every type around it.
    func position(of alias: TypealiasFact, from context: ResolutionContext) -> ResolutionContext {
        // Only the alias's own surroundings are visible, never the referencing function's locals.
        let localOwners = alias.localTo.map { [$0] } ?? []
        let path = alias.localTo == nil ? alias.typePath : [NameLookup.localMarker] + alias.typePath
        let owner = alias.typePath.isEmpty ? nil : type(atPath: path, from: alias.file, localOwners: localOwners)
        let chain = owner.map(chain(from:)) ?? []
        var generics = Set(alias.genericParameters)
        for key in chain {
            generics.formUnion(entries[key]?.genericParameters ?? [])
        }
        return ResolutionContext(
            file: alias.file,
            knownModules: context.knownModules,
            importsXCTest: context.importsXCTest,
            importsFoundation: context.importsFoundation,
            chain: chain,
            genericParameters: generics,
            localOwners: localOwners
        )
    }

    /// `Module.Name` and `Module::Name`.
    private func resolveQualified(
        module qualifier: String,
        rest: [String],
        context: ResolutionContext,
        visiting: inout Set<String>
    ) -> TypeResolution {
        let dotted = rest.joined(separator: ".")
        if qualifier == module {
            let topLevel = ResolutionContext(
                file: context.file,
                knownModules: [],
                importsXCTest: context.importsXCTest,
                importsFoundation: context.importsFoundation,
                chain: [],
                genericParameters: [],
                localOwners: []
            )
            return resolve(SpelledType(components: rest, moduleSelector: nil), from: topLevel, visiting: &visiting)
        }
        let isPlatform = PlatformModules.harvested.contains(qualifier)
            || (qualifier == PlatformModules.xcTest && context.importsXCTest)
        let isPlatformName = isPlatform && isPlatformType(dotted, rest.first, context: context)
        return isPlatformName ? .platform(dotted) : .external(dotted)
    }

    /// A name the module does not declare.
    private func fallback(_ components: [String], context: ResolutionContext) -> TypeResolution {
        let dotted = components.joined(separator: ".")
        if isPlatformType(dotted, components.first, context: context) {
            return .platform(dotted)
        }
        if let root = components.first, nestedNames.contains(root) {
            return .unresolved
        }
        return .external(dotted)
    }

    /// Whether the platform table holds `dotted`, or its root.
    func isPlatformType(_ dotted: String, _ root: String?, context: ResolutionContext) -> Bool {
        let names = [dotted, root].compactMap(\.self)
        return names.contains { platform.types.contains($0) || (context.importsXCTest && platform.xcTest.contains($0)) }
    }

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
        for type in context.chain {
            for candidate in [type] + superclasses(of: type) {
                if nestedTypes(named: name, of: candidate, from: context.file).isEmpty == false {
                    return nil
                }
                if let found = entries[candidate]?.typealiases[name] {
                    return found
                }
            }
        }
        if context.localOwners.contains(where: { locals[$0]?[[name]] != nil })
            || visible(byPath[[name]] ?? [], from: context.file).isEmpty == false {
            return nil
        }
        return visibleAliases(name, from: context.file).first
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
        // `String.Transform`: an alias in an extension group sits on its written path.
        guard let key = owner.moduleKey ?? extensionGroups[ownerPath],
              nestedTypes(named: name, of: key, from: context.file).isEmpty else {
            return nil
        }
        return entries[key]?.typealiases[name]
    }

    /// Top-level typealiases named `name` that `file` can see.
    private func visibleAliases(_ name: String, from file: String) -> [TypealiasFact] {
        (aliases[name] ?? []).filter { $0.isFileScoped == false || $0.file == file }
    }

    /// The nested types named `name` of `type`, local or not.
    private func nestedTypes(named name: String, of type: TypeKey, from file: String) -> [TypeKey] {
        if let owner = type.localTo {
            return locals[owner]?[type.path + [name]].map { [$0] } ?? []
        }
        return visible(byPath[type.path + [name]] ?? [], from: file)
    }
}
