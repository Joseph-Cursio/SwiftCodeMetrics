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
    static let maximumSettlingPasses = 4

    /// The module name.
    let module: String
    /// The platform names.
    let platform: PlatformTable
    /// Types by key.
    var entries: [TypeKey: TypeEntry] = [:]
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
    var extensionGroups: [[String]: TypeKey] = [:]
    /// Extensions of a missing nested type of a module type (Spec §2.2).
    var unresolvedExtensions: [ExtensionDeclFact] = []
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
        let context = declarationContext(of: key)
        if let entry = entries[key], entry.kind == .class,
           let parent = firstEntry(of: entry).lazy.compactMap({ self.moduleClass($0, from: context) }).first,
           parent != key {
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
    func resetMemos() {
        pathMemo = [:]
        superclassMemo = [:]
    }

    /// Adds a type at `path`, merging `#if` variants that share a key. A
    /// provisional extension group under that key gives way.
    func register(_ fact: TypeFact, path: [String]) {
        let key = TypeKey(
            module: module,
            path: path,
            file: fact.isFileScoped ? fact.file : nil,
            localTo: fact.localTo
        )
        if var entry = entries[key], entry.kind != .extensionGroup {
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

    /// Resolves extensions, and types declared inside them, until nothing
    /// changes. Extension groups register whenever the rest is stuck, so a
    /// typealias one declares (`extension String { typealias Owner = User }`)
    /// resolves `extension String.Owner` and types nested in it, whatever the
    /// source order.
    private func mergeExtensions(types: [TypeFact], extensions: [ExtensionDeclFact]) {
        var pendingTypes = types
        var pendingExtensions = Array(extensions.indices)
        var merged: [MergedExtension] = []
        var areGroupsCurrent = false
        while true {
            var progress = false
            pendingTypes = pendingTypes.filter { fact in
                let prefix = Array(fact.path.prefix(fact.extensionPathLength))
                guard let base = moduleType(atPath: prefix, from: fact.file) else {
                    return true
                }
                register(fact, path: base.path + fact.path.dropFirst(fact.extensionPathLength))
                resetMemos()
                progress = true
                return false
            }
            pendingExtensions = pendingExtensions.filter { index in
                guard let key = moduleTarget(of: extensions[index]) else {
                    return true
                }
                merge(extensions[index], into: key)
                merged.append(MergedExtension(index: index, fact: extensions[index], key: key))
                resetMemos()
                progress = true
                return false
            }
            if progress {
                areGroupsCurrent = false
            } else if areGroupsCurrent == false {
                _ = registerGroups(pendingExtensions.map { extensions[$0] })
                areGroupsCurrent = true
            } else if pendingTypes.isEmpty {
                break
            } else {
                // Types nested in an extension of a platform or external type sit
                // under the group's key: `extension String { enum Limits }`. The
                // shortest prefixes go first, so `extension Celsius.Unit { struct
                // Deep }` then finds `Unit` under `Double`.
                pendingTypes = registerInGroups(pendingTypes)
                areGroupsCurrent = false
            }
        }
        settleWithGroups(&merged, pending: pendingExtensions, extensions: extensions)
    }

    /// Settles merged extensions and groups together until neither changes:
    /// an extension that a group's typealias resolves merges into its type,
    /// and a typealias it brings can move another merged extension.
    private func settleWithGroups(
        _ merged: inout [MergedExtension],
        pending: [Int],
        extensions: [ExtensionDeclFact]
    ) {
        var grouped = pending
        for _ in 0..<Self.maximumSettlingPasses {
            let released = settle(&merged)
            grouped = (grouped + released).sorted()
            let resolved = registerGroups(grouped.map { extensions[$0] })
            guard released.isEmpty == false || resolved.isEmpty == false else {
                return
            }
            for (position, key) in resolved {
                let index = grouped[position]
                merge(extensions[index], into: key)
                merged.append(MergedExtension(index: index, fact: extensions[index], key: key))
            }
            let moved = Set(resolved.map { grouped[$0.position] })
            grouped.removeAll(where: moved.contains)
            resetMemos()
        }
        _ = registerGroups(grouped.map { extensions[$0] })
    }

    /// Adds an extension's members, typealiases and facts to `key`.
    func merge(_ fact: ExtensionDeclFact, into key: TypeKey) {
        entries[key]?.members += fact.members
        for alias in fact.typealiases {
            entries[key]?.add(alias)
        }
        entries[key]?.extensionFacts.append(fact)
    }

    deinit {
        // Nothing to release beyond stored properties.
    }
}
