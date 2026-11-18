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
    /// Extension groups by written path: member lookup only, never a type reference.
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
        var resolved = extensionGroups[path]
        let spelled = SpelledType(components: path, moduleSelector: nil)
        if case .module(let key) = resolve(spelled, from: topLevelContext(file: file)) {
            resolved = key
        }
        // A type nested in a group keyed by its resolved name: `extension Swift.String { enum Limits }`.
        for length in stride(from: path.count - 1, to: 0, by: -1) where resolved == nil {
            if let group = extensionGroups[Array(path.prefix(length))] {
                resolved = visible(byPath[group.path + path.dropFirst(length)] ?? [], from: file).first
            }
        }
        pathMemo[file, default: [:]][path] = resolved
        return resolved
    }

    /// The enclosing types of `key`, innermost first, the type itself included.
    func chain(from key: TypeKey) -> [TypeKey] {
        var visited: Set<TypeKey> = []
        return chain(from: key, visited: &visited)
    }

    /// The chain, with a guard against cycles through local owners.
    private func chain(from key: TypeKey, visited: inout Set<TypeKey>) -> [TypeKey] {
        guard visited.insert(key).inserted else {
            return []
        }
        var chain = [key]
        var path = key.path
        while path.count > 1 {
            path.removeLast()
            let localParent = key.localTo.flatMap { locals[$0]?[path] }
            let parent = localParent ?? visible(byPath[path] ?? [], from: key.file ?? "").first ?? extensionGroups[path]
            if let parent {
                chain.append(parent)
            }
        }
        // A local type also sees the types around the function that owns it.
        guard let owner = key.localTo, let first = key.path.first, let outermost = locals[owner]?[[first]],
              let entry = entries[outermost], entry.enclosingTypePath.isEmpty == false else {
            return chain
        }
        let enclosingPath = entry.enclosingLocalOwner == nil
            ? entry.enclosingTypePath
            : [NameLookup.localMarker] + entry.enclosingTypePath
        let localOwners = entry.enclosingLocalOwner.map { [$0] } ?? []
        if let enclosing = type(atPath: enclosingPath, from: entry.file, localOwners: localOwners) {
            chain += self.chain(from: enclosing, visited: &visited)
        }
        return chain
    }

    /// The keys visible from `file`: not file-scoped, or declared there.
    func visible(_ keys: [TypeKey], from file: String) -> [TypeKey] {
        keys.filter { $0.file == nil || $0.file == file }
    }

    // MARK: - Building

    /// Where a type's own declaration resolves names from.
    private func declarationContext(of key: TypeKey) -> ResolutionContext {
        let parents = Array(chain(from: key).dropFirst())
        return ResolutionContext(
            file: entries[key]?.file ?? "",
            knownModules: [module],
            importsXCTest: false,
            importsFoundation: false,
            chain: parents,
            genericParameters: entries[key]?.genericParameters ?? [],
            localOwners: key.localTo.map { [$0] } ?? []
        )
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
        var pendingExtensions = extensions
        var progress = true
        while progress || pendingTypes.isEmpty == false {
            if progress == false {
                // Types nested in an extension of a platform or external type
                // keep their written path: `extension String { enum Limits }`.
                for fact in pendingTypes {
                    let prefix = Array(fact.path.prefix(fact.extensionPathLength))
                    register(fact, path: groupPath(for: prefix, from: fact.file) + fact.path.dropFirst(prefix.count))
                }
                pendingTypes = []
                pathMemo = [:]
            }
            progress = false
            pendingTypes = pendingTypes.filter { fact in
                let prefix = Array(fact.path.prefix(fact.extensionPathLength))
                guard let base = type(atPath: prefix, from: fact.file, localOwners: []) else {
                    return true
                }
                register(fact, path: base.path + fact.path.dropFirst(fact.extensionPathLength))
                pathMemo = [:]
                progress = true
                return false
            }
            pendingExtensions = pendingExtensions.filter { fact in
                guard let key = type(atPath: fact.extended.components, from: fact.file, localOwners: []) else {
                    return true
                }
                entries[key]?.members += fact.members
                for alias in fact.typealiases {
                    entries[key]?.add(alias)
                }
                entries[key]?.extensionFacts.append(fact)
                pathMemo = [:]
                progress = true
                return false
            }
        }
        registerExtensionGroups(pendingExtensions)
    }

    /// Extensions of a type the module does not declare form extension
    /// groups (Spec §2.2): members and typealiases, no stored state.
    private func registerExtensionGroups(_ extensions: [ExtensionDeclFact]) {
        for fact in extensions {
            // `extension Feature.State` where `Feature` is a module type with no
            // nested `State` is an unresolved extension (Spec §2.2), not a group.
            if isMissingNestedType(fact.extended.components, from: fact.file) {
                unresolvedExtensions.append(fact)
                continue
            }
            let path = groupPath(for: fact.extended.components, from: fact.file)
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
            extensionGroups[fact.extended.components] = key
            entries[key]?.members += fact.members
            for alias in fact.typealiases {
                entries[key]?.add(alias)
            }
            entries[key]?.extensionFacts.append(fact)
        }
        pathMemo = [:]
    }

    deinit {
        // Nothing to release beyond stored properties.
    }
}
