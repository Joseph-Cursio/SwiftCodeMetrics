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
        if let qualified = resolveDotted(components, context: context, visiting: &visiting) {
            return qualified
        }
        if context.genericParameters.contains(root) {
            return .genericParameter
        }
        if root == "Self" {
            guard let current = context.chain.first else {
                return .genericParameter
            }
            let rest = components.dropFirst()
            if entries[current]?.kind == .extensionGroup {
                return resolveInGroup(current, rest: rest, context: context, visiting: &visiting)
            }
            // `Self.State` names an associated type or generic parameter.
            if let member = rest.first, entries[current]?.genericParameters.contains(member) == true {
                return .genericParameter
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

    /// `Module.Name` written with a dot, when the root is a known module
    /// that no module type shadows.
    private func resolveDotted(
        _ components: [String],
        context: ResolutionContext,
        visiting: inout Set<String>
    ) -> TypeResolution? {
        guard components.count > 1, let root = components.first, context.knownModules.contains(root),
              visible(byPath[[root]] ?? [], from: context.file).isEmpty else {
            return nil
        }
        // A type nested in a group that keeps its written path: `extension Swift.Result { struct Box }`.
        if let exact = visible(byPath[components] ?? [], from: context.file).first {
            return .module(exact)
        }
        let rest = Array(components.dropFirst())
        return resolveQualified(module: root, rest: rest, context: context, visiting: &visiting)
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
        let aliases = visibleAliases(name, from: context.file)
        guard let first = aliases.first else {
            return nil
        }
        let expanded = expand(first, context: context, visiting: &visiting)
        // `#if` variants of one alias that reach different types are ambiguous.
        for other in aliases.dropFirst() where expand(other, context: context, visiting: &visiting) != expanded {
            return .ambiguous
        }
        return expanded
    }

    /// `Self` and `Self.X` inside an extension group: the group's own nested
    /// types and typealiases first, then the extended type itself, with a
    /// module typealias expanded (`extension Celsius` where `Celsius = Double`).
    private func resolveInGroup(
        _ group: TypeKey,
        rest: ArraySlice<String>,
        context: ResolutionContext,
        visiting: inout Set<String>
    ) -> TypeResolution {
        if let member = rest.first, let found = memberType(member, of: group, context: context, visiting: &visiting) {
            return descend(from: found, through: rest.dropFirst(), context: context, visiting: &visiting)
        }
        // The group's path may carry a module qualifier: `extension Swift.Result`.
        let extended = resolve(
            SpelledType(components: group.path, moduleSelector: nil),
            from: groupScope(of: context),
            visiting: &visiting
        )
        return descend(from: extended, through: rest, context: context, visiting: &visiting)
    }

    /// File scope with every platform and imported module known as a qualifier.
    private func groupScope(of context: ResolutionContext) -> ResolutionContext {
        ResolutionContext(
            file: context.file,
            knownModules: importedModules.union(PlatformModules.harvested).union([module]),
            importsXCTest: context.importsXCTest,
            importsFoundation: context.importsFoundation,
            chain: [],
            genericParameters: [],
            localOwners: []
        )
    }

    /// `context` at file scope: no enclosing types, generics or locals.
    private func fileScope(of context: ResolutionContext) -> ResolutionContext {
        ResolutionContext(
            file: context.file,
            knownModules: [],
            importsXCTest: context.importsXCTest,
            importsFoundation: context.importsFoundation,
            chain: [],
            genericParameters: [],
            localOwners: []
        )
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
        if entries[type]?.conflictingAliases.contains(name) == true {
            return .ambiguous
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
                // Nested types of the in-module superclass chain are reachable too (§7.3 step 3).
                var found = memberType(component, of: key, context: context, visiting: &visiting)
                for parent in superclasses(of: key) where found == nil {
                    found = memberType(component, of: parent, context: context, visiting: &visiting)
                }
                current = found ?? .unresolved

            case .platform(let name):
                current = groupNested(name, component, file: context.file) ?? .platform(name + "." + component)

            case .external(let name):
                current = groupNested(name, component, file: context.file) ?? .external(name + "." + component)

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
            return resolve(
                SpelledType(components: rest, moduleSelector: nil),
                from: fileScope(of: context),
                visiting: &visiting
            )
        }
        let isPlatform = PlatformModules.harvested.contains(qualifier)
            || (qualifier == PlatformModules.xcTest && context.importsXCTest)
        let isPlatformName = isPlatform && isPlatformType(dotted, rest.first, context: context)
        guard let root = rest.first else {
            return .unresolved
        }
        // `Swift.String.Limits` reaches the module's type nested in the String group.
        let start: TypeResolution = isPlatformName ? .platform(root) : .external(root)
        return descend(from: start, through: rest.dropFirst(), context: context, visiting: &visiting)
    }

    /// The module type nested in the group for the platform or external
    /// type `name`: `Double.Scale` for `extension Double { enum Scale }`.
    /// Never one nested in a module type that shadows the name.
    private func groupNested(_ name: String, _ component: String, file: String) -> TypeResolution? {
        let base = name.split(separator: ".").map(String.init)
        guard let root = base.first, visible(byPath[[root]] ?? [], from: file).isEmpty else {
            return nil
        }
        let nested = visible(byPath[base + [component]] ?? [], from: file)
        guard let only = nested.first else {
            return nil
        }
        return nested.count == 1 ? .module(only) : .ambiguous
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

    /// Top-level typealiases named `name` that `file` can see.
    func visibleAliases(_ name: String, from file: String) -> [TypealiasFact] {
        (aliases[name] ?? []).filter { $0.isFileScoped == false || $0.file == file }
    }
}
