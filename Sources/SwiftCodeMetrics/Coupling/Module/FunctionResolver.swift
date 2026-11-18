//
//  FunctionResolver.swift
//  SwiftCodeMetrics
//
//  Resolves one function's raw references against the symbol table:
//  value names by Spec §7.2, type-name candidates by §7.3.
//

/// Resolves the references of one function.
struct FunctionResolver {
    /// The member names that are never statics (Spec §8.2).
    static let nonStaticMembers: Set<String> = ["Protocol", "Type", "init", "self"]
    /// The prefix that marks a `Module::` selector at the root of a dotted base.
    static let selectorMarker = "::"

    /// Static names that count as singletons on types outside the module (Spec §8.2).
    static let externalSingletonNames: Set<String> = ["current", "default", "main", "shared", "standard"]

    /// The module's table.
    let table: SymbolTable
    /// The raw references.
    let raw: RawFunctionReferences
    /// Where names resolve from.
    let context: ResolutionContext
    /// The options.
    let options: MetricsOptions

    /// A resolver for `raw` in a file with `imports`.
    init(table: SymbolTable, raw: RawFunctionReferences, imports: [ImportFact], options: MetricsOptions) {
        self.table = table
        self.raw = raw
        self.options = options
        let imported = Set(imports.map(\.module))
        let importsXCTest = imported.contains(PlatformModules.xcTest)
        let current = Self.currentType(raw.context, table: table)
        let chain = current.map(table.chain(from:)) ?? []
        var generics = Set(raw.context.genericParameters)
        for key in chain {
            generics.formUnion(table.entries[key]?.genericParameters ?? [])
        }
        context = ResolutionContext(
            file: raw.context.file,
            knownModules: imported
                .union(PlatformModules.harvested)
                .union([table.module] + (importsXCTest ? [PlatformModules.xcTest] : [])),
            importsXCTest: importsXCTest,
            importsFoundation: imported.isDisjoint(with: PlatformModules.foundationExporters) == false,
            chain: chain,
            genericParameters: generics,
            localOwners: raw.context.enclosingRecords.reversed()
        )
    }

    /// The current type of a function, from its stored context.
    private static func currentType(_ context: FunctionContext, table: SymbolTable) -> TypeKey? {
        guard context.typePath.isEmpty == false else {
            return nil
        }
        if let owner = context.localOwner {
            return table.type(
                atPath: [NameLookup.localMarker] + context.typePath,
                from: context.file,
                localOwners: [owner]
            )
        }
        return table.type(atPath: context.typePath, from: context.file, localOwners: [])
    }

    /// Resolves a bare value name from its lookup results (Spec §7.2).
    func resolveValue(_ name: String, lookup: [StoredLookupResult]) -> ValueResolution {
        if name.hasPrefix("$") {
            return .notCoupling
        }
        var seenInnermost = false
        for result in lookup {
            switch result {
            case .local:
                return .notCoupling

            case .implicitClosureParameters:
                continue

            case .genericParameters(let path):
                if let key = type(atPath: path), table.entries[key]?.genericParameters.contains(name) == true {
                    return .notCoupling
                }

            case .members(let path):
                let key = type(atPath: path)
                defer { seenInnermost = true }
                guard let key else {
                    continue
                }
                if let found = seenInnermost ? enclosingStatic(name, in: key) : innermostMember(name, in: key) {
                    return found
                }
            }
        }
        if let global = table.global(name, from: context.file) {
            return .global(global)
        }
        return table.isFreeFunction(name, from: context.file) ? .freeFunction : .unresolved
    }

    /// Classifies an uppercase name in expression position (Spec §7.3).
    func classifyCandidate(_ name: String, lookup: [StoredLookupResult]) -> CandidateClass {
        guard context.knownModules.contains(name) == false else {
            return .notCandidate
        }
        let value = resolveValue(name, lookup: lookup)
        switch value {
        case .enumCase, .inheritedMember, .notCoupling, .ownMember, .staticMember:
            return .notCandidate

        case .freeFunction, .global, .unresolved:
            break
        }
        let resolved = table.resolve(SpelledType(components: [name], moduleSelector: nil), from: context)
        switch resolved {
        case .ambiguous, .genericParameter, .module, .opaqueAlias, .platform:
            return .type(resolved)

        case .external, .unresolved:
            if table.isFreeFunction(name, from: context.file) || isPlatformFreeFunction(name) {
                return .freeFunction
            }
            if case .global(let global) = value {
                return .global(global)
            }
            if context.importsFoundation, isNSClassName(name) {
                return .type(.platform(name))
            }
            return .type(resolved)
        }
    }

    /// Whether `name` is a platform free function in this file.
    func isPlatformFreeFunction(_ name: String) -> Bool {
        table.platform.freeFunctions.contains(name)
            || (context.importsXCTest && table.platform.xcTestFreeFunctions.contains(name))
    }

    /// A dotted base as a type name: a `::Module` root becomes the module selector.
    func spelledBase(_ base: [String]) -> SpelledType {
        guard let root = base.first, root.hasPrefix(Self.selectorMarker) else {
            return SpelledType(components: base, moduleSelector: nil)
        }
        let module = String(root.dropFirst(Self.selectorMarker.count))
        return SpelledType(components: Array(base.dropFirst()), moduleSelector: module)
    }

    /// A dotted base as a key spells it: `Self` is the current type's path,
    /// and a selector is dropped.
    func displayBase(_ base: [String]) -> String {
        var components = spelledBase(base).components
        if components.first == "Self", let current = context.chain.first {
            components = current.path + components.dropFirst()
        }
        return components.joined(separator: ".")
    }

    /// The type a stored lookup path names.
    func type(atPath path: [String]) -> TypeKey? {
        table.type(atPath: path, from: context.file, localOwners: context.localOwners)
    }

    /// The members named `name` on `key` and its superclass chain, nearest first.
    func members(named name: String, of key: TypeKey) -> [(owner: TypeKey, member: MemberFact)] {
        ([key] + table.superclasses(of: key)).flatMap { owner in
            (table.entries[owner]?.members ?? []).filter { $0.name == name }.map { (owner, $0) }
        }
    }

    /// A name on the innermost type, or its superclass chain.
    private func innermostMember(_ name: String, in key: TypeKey) -> ValueResolution? {
        let own = (table.entries[key]?.members ?? []).filter { $0.name == name }
        if own.isEmpty == false {
            return pick(own, owner: key, isInherited: false)
        }
        for parent in table.superclasses(of: key) {
            let inherited = (table.entries[parent]?.members ?? []).filter { $0.name == name }
            if inherited.isEmpty == false {
                return pick(inherited, owner: parent, isInherited: true)
            }
        }
        return nil
    }

    /// A static of an enclosing type; instance members are unreachable by bare name.
    private func enclosingStatic(_ name: String, in key: TypeKey) -> ValueResolution? {
        let statics = (table.entries[key]?.members ?? []).filter { $0.name == name && $0.isTypeLevel }
        guard let member = MemberFact.firstProperty(statics) ?? statics.first else {
            return nil
        }
        return member.kind == .enumCase ? .enumCase(key) : .staticMember(key, member)
    }

    /// Chooses between a static and an instance member of one type.
    private func pick(_ matches: [MemberFact], owner: TypeKey, isInherited: Bool) -> ValueResolution {
        let statics = matches.filter { $0.isTypeLevel && $0.kind != .enumCase }
        let instances = matches.filter { $0.isTypeLevel == false }
        if let member = MemberFact.firstProperty(statics) ?? statics.first,
           instances.isEmpty || raw.context.isTypeLevel {
            return .staticMember(owner, member)
        }
        if instances.isEmpty == false {
            return isInherited ? .inheritedMember : .ownMember
        }
        return .enumCase(owner)
    }

    /// `^NS[A-Z]`.
    private func isNSClassName(_ name: String) -> Bool {
        let prefix = "NS"
        return name.hasPrefix(prefix) && name.dropFirst(prefix.count).first?.isUppercase == true
    }
}
