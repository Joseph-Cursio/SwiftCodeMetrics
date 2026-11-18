//
//  SymbolTable.swift
//  SwiftCodeMetrics
//
//  The module symbol table (Spec §7.1): every type merged with its
//  extensions across files, plus globals, free functions and typealiases.
//  Extensions resolve through the same type resolution as references, so
//  an extension of a nested or aliased type lands on the right type.
//

/// One module's declarations, merged.
final class SymbolTable {
    /// How many times merged extensions are re-resolved before the table settles.
    private static let maximumSettlingPasses = 4

    /// The module name.
    let module: String
    /// The platform names.
    let platform: PlatformTable
    /// Types by key.
    private(set) var entries: [TypeKey: TypeEntry] = [:]
    /// Module globals by name.
    private(set) var globals: [String: [GlobalFact]] = [:]
    /// Module free function names.
    private(set) var freeFunctions: [String: [FreeFunctionFact]] = [:]

    /// Non-local types by nominal path.
    private(set) var byPath: [[String]: [TypeKey]] = [:]
    /// Local types by owning function, then path.
    private(set) var locals: [MemberKey: [[String]: TypeKey]] = [:]
    /// Top-level typealiases by name.
    private(set) var aliases: [String: [TypealiasFact]] = [:]
    /// Simple names of every nested type, to tell unreachable from external.
    private(set) var nestedNames: Set<String> = []
    /// Extension groups by key path: member lookup only, never a type reference.
    private(set) var extensionGroups: [[String]: TypeKey] = [:]
    /// Extensions of a missing nested type of a module type (Spec §2.2).
    private(set) var unresolvedExtensions: [ExtensionDeclFact] = []
    /// Names of `macro` declarations in the module.
    private(set) var macroNames: Set<String> = []
    /// Every module some file imports, for module qualifiers on extensions.
    private(set) var importedModules: Set<String> = []
    /// Superclass chains already computed.
    private var superclassMemo: [TypeKey: [TypeKey]] = [:]
    /// Resolved type paths, per file.
    private var pathMemo: [String: [[String]: TypeKey?]] = [:]

    /// Builds the table from every file of the module.
    init(module: String, files: [FileAnalysis], platform: PlatformTable) {
        self.module = module
        self.platform = platform
        var pendingTypes: [TypeFact] = []
        var pendingExtensions: [ExtensionDeclFact] = []
        for file in files {
            for fact in file.declarations.types {
                if fact.extensionPathLength == 0 {
                    register(fact, path: fact.path)
                } else {
                    pendingTypes.append(fact)
                }
            }
            pendingExtensions += file.declarations.extensions
            for global in file.declarations.globals {
                globals[global.name, default: []].append(global)
            }
            for function in file.declarations.freeFunctions {
                freeFunctions[function.name, default: []].append(function)
            }
            for alias in file.declarations.typealiases {
                aliases[alias.name, default: []].append(alias)
            }
            macroNames.formUnion(file.declarations.macroNames)
            importedModules.formUnion(file.imports.map(\.module))
        }
        mergeExtensions(types: pendingTypes, extensions: pendingExtensions)
    }

    // MARK: - Lookups

    /// The in-module superclass chain of a class, nearest first (Spec §7.3).
    func superclasses(of key: TypeKey) -> [TypeKey] {
        if let known = superclassMemo[key] {
            return known
        }
        superclassMemo[key] = []
        var chain: [TypeKey] = []
        if let entry = entries[key], entry.kind == .class, let first = entry.inherited.first,
           let parent = moduleClass(first, from: declarationContext(of: key)), parent != key {
            chain = [parent] + superclasses(of: parent).filter { $0 != key }
        }
        superclassMemo[key] = chain
        return chain
    }

    /// The type a lexical or extension path names, from `file`.
    func type(atPath path: [String], from file: String, localOwners: [MemberKey]) -> TypeKey? {
        if path.first == NameLookup.localMarker {
            let relative = Array(path.dropFirst())
            return localOwners.lazy.compactMap { self.locals[$0]?[relative] }.first
        }
        if let exact = visible(byPath[path] ?? [], from: file).first {
            return exact
        }
        if let known = pathMemo[file]?[path] {
            return known
        }
        let spelled = SpelledType(components: path, moduleSelector: nil)
        let resolution = resolve(spelled, from: qualifierContext(file: file))
        // A type nested in a group resolves to the module type: `Swift.String.Limits`, `Celsius.Scale`.
        // A path that is an unresolved extension from this file names no
        // group, even one another file registered under the same spelling.
        let resolved = resolution.moduleKey
            ?? (isMissingNestedType(path, from: file) ? nil : groupKey(for: path, from: file))
        pathMemo[file, default: [:]][path] = resolved
        return resolved
    }

    // MARK: - Building

    /// Forgets resolved paths and superclass chains after the table grows.
    private func resetMemos() {
        pathMemo = [:]
        superclassMemo = [:]
    }

    /// Adds a type at `path`, merging `#if` variants that share a key.
    private func register(_ fact: TypeFact, path: [String]) {
        let key = TypeKey(
            module: module,
            path: path,
            file: fact.isFileScoped ? fact.file : nil,
            localTo: fact.localTo
        )
        if var entry = entries[key] {
            entry.members += fact.members
            entry.genericParameters.formUnion(fact.genericParameters + fact.associatedTypes)
            if entry.inherited.isEmpty {
                entry.inherited = fact.inherited
            }
            for alias in fact.typealiases {
                entry.add(alias)
            }
            entry.declarations.append(fact)
            entries[key] = entry
            return
        }
        var entry = TypeEntry(
            key: key,
            kind: fact.kind,
            genericParameters: Set(fact.genericParameters + fact.associatedTypes),
            inherited: fact.inherited,
            members: fact.members,
            file: fact.file
        )
        entry.enclosingTypePath = fact.enclosingTypePath
        entry.enclosingLocalOwner = fact.enclosingLocalOwner
        entry.declarations = [fact]
        for alias in fact.typealiases {
            entry.add(alias)
        }
        entries[key] = entry
        if let owner = fact.localTo {
            locals[owner, default: [:]][path] = key
        } else {
            byPath[path, default: []].append(key)
        }
        if path.count > 1, let last = path.last {
            nestedNames.insert(last)
        }
    }

    /// Resolves extensions, and types declared inside them, until nothing changes.
    private func mergeExtensions(types: [TypeFact], extensions: [ExtensionDeclFact]) {
        var pendingTypes = types
        var pendingExtensions = Array(extensions.indices)
        var merged: [MergedExtension] = []
        var progress = true
        while progress || pendingTypes.isEmpty == false {
            if progress == false {
                // Types nested in an extension of a platform or external type sit
                // under the group's key: `extension String { enum Limits }`. The
                // shortest prefixes go first, so `extension Celsius.Unit { struct
                // Deep }` then finds `Unit` under `Double`.
                pendingTypes = registerInGroups(pendingTypes)
            }
            progress = false
            pendingTypes = pendingTypes.filter { fact in
                let prefix = Array(fact.path.prefix(fact.extensionPathLength))
                guard let base = type(atPath: prefix, from: fact.file, localOwners: []) else {
                    return true
                }
                register(fact, path: base.path + fact.path.dropFirst(fact.extensionPathLength))
                resetMemos()
                progress = true
                return false
            }
            pendingExtensions = pendingExtensions.filter { index in
                guard let key = target(of: extensions[index]) else {
                    return true
                }
                merge(extensions[index], into: key)
                merged.append(MergedExtension(index: index, fact: extensions[index], key: key))
                resetMemos()
                progress = true
                return false
            }
        }
        let released = settle(&merged)
        registerExtensionGroups((pendingExtensions + released).sorted().map { extensions[$0] })
    }

    /// Adds an extension's members, typealiases and facts to `key`.
    private func merge(_ fact: ExtensionDeclFact, into key: TypeKey) {
        entries[key]?.members += fact.members
        for alias in fact.typealiases {
            entries[key]?.add(alias)
        }
        entries[key]?.extensionFacts.append(fact)
    }

    /// Registers the shortest pending types nested in groups, under the
    /// group's key: `extension String { enum Limits }`. Shortest first, so
    /// `extension Celsius.Unit { struct Deep }` then finds `Unit` under
    /// `Double`; one whose prefix no longer resolves, because the table is
    /// half built, waits for the next round. Returns the types still pending.
    private func registerInGroups(_ pending: [TypeFact]) -> [TypeFact] {
        let shortest = pending.map(\.extensionPathLength).min() ?? 0
        var registered = false
        var remaining: [TypeFact] = []
        for fact in pending {
            let prefix = Array(fact.path.prefix(fact.extensionPathLength))
            let isHalfBuilt = registered && resolve(
                SpelledType(components: prefix, moduleSelector: nil),
                from: qualifierContext(file: fact.file)
            ) == .unresolved
            guard fact.extensionPathLength == shortest, isHalfBuilt == false else {
                remaining.append(fact)
                continue
            }
            register(fact, path: groupPath(for: prefix, from: fact.file) + fact.path.dropFirst(prefix.count))
            registered = true
            resetMemos()
        }
        return remaining
    }

    /// Resolves every merged extension again against the finished table and
    /// moves the ones whose type changed: `extension Outer.Config` merged
    /// into an inherited `Base.Config` before `extension Outer { typealias
    /// Config = Settings }` was read belongs to Settings. One whose path now
    /// names a platform, external or ambiguous type leaves the module type;
    /// its index is returned so it becomes a group or an unresolved extension.
    private func settle(_ merged: inout [MergedExtension]) -> [Int] {
        var released: [Int] = []
        for _ in 0..<Self.maximumSettlingPasses {
            resetMemos()
            let targets = merged.map(settledTarget)
            guard targets != merged.map(\.key) else {
                break
            }
            for key in Set(merged.map(\.key) + targets.compactMap(\.self)) {
                entries[key]?.resetToDeclarations()
            }
            var staying: [MergedExtension] = []
            for (index, target) in targets.enumerated() {
                guard let target else {
                    released.append(merged[index].index)
                    continue
                }
                merge(merged[index].fact, into: target)
                staying.append(MergedExtension(index: merged[index].index, fact: merged[index].fact, key: target))
            }
            merged = staying
        }
        resetMemos()
        return released
    }

    /// Extensions of a type the module does not declare form extension
    /// groups (Spec §2.2): members and typealiases, no stored state.
    private func registerExtensionGroups(_ extensions: [ExtensionDeclFact]) {
        for fact in extensions {
            // `extension Feature.State` where `Feature` is a module type with no
            // nested `State` is an unresolved extension (Spec §2.2), not a group.
            if isMissingNestedType(fact.extended.extensionPath(in: module), from: fact.file) {
                unresolvedExtensions.append(fact)
                continue
            }
            let path = groupPath(for: fact.extended.extensionPath(in: module), from: fact.file)
            let key = TypeKey(module: module, path: path)
            if entries[key] == nil {
                entries[key] = TypeEntry(
                    key: key,
                    kind: .extensionGroup,
                    genericParameters: [],
                    inherited: [],
                    members: [],
                    file: fact.file
                )
                extensionGroups[path] = key
            }
            entries[key]?.members += fact.members
            for alias in fact.typealiases {
                entries[key]?.add(alias)
            }
            entries[key]?.extensionFacts.append(fact)
        }
        resetMemos()
    }

    deinit {
        // Nothing to release beyond stored properties.
    }
}
