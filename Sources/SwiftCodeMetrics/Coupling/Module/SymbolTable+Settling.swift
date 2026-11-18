//
//  SymbolTable+Settling.swift
//  SwiftCodeMetrics
//
//  Registering types nested in groups, extension groups and unresolved
//  extensions, and settling merged extensions once the table is complete
//  (Spec §2.2).
//

extension SymbolTable {
    /// Registers the shortest pending types nested in groups, under the
    /// group's key: `extension String { enum Limits }`. Shortest first, so
    /// `extension Celsius.Unit { struct Deep }` then finds `Unit` under
    /// `Double`; one whose prefix no longer resolves, because the table is
    /// half built, waits for the next round. Returns the types still pending.
    func registerInGroups(_ pending: [TypeFact]) -> [TypeFact] {
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
    func settle(_ merged: inout [MergedExtension]) -> [Int] {
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

    /// Registers the extension groups `extensions` form (Spec §2.2): members
    /// and typealiases, no stored state. Their keys are worked out again with
    /// the groups just registered until they stop changing, so a group's
    /// typealias resolves another extension's path. Returns the extensions,
    /// by position, whose path names a module type: those merge instead.
    func registerGroups(_ extensions: [ExtensionDeclFact]) -> [(position: Int, key: TypeKey)] {
        var placed: [GroupPlacement] = []
        for _ in 0..<Self.maximumSettlingPasses {
            resetMemos()
            let placements = extensions.map(placement)
            let resolved = placements.enumerated().compactMap { position, placement in
                placement.moduleKey.map { (position: position, key: $0) }
            }
            guard resolved.isEmpty else {
                return resolved
            }
            guard placements != placed else {
                break
            }
            clearGroups()
            for (fact, placement) in zip(extensions, placements) {
                register(fact, at: placement)
            }
            placed = placements
        }
        resetMemos()
        return []
    }

    /// Where an extension goes once groups are registered.
    private func placement(of fact: ExtensionDeclFact) -> GroupPlacement {
        let path = fact.extended.extensionPath(in: module)
        if let key = moduleTarget(of: fact) {
            return .module(key)
        }
        // `extension Feature.State` where `Feature` is a module type with no
        // nested `State` is an unresolved extension (Spec §2.2), not a group.
        if isMissingNestedType(path, from: fact.file) {
            return .unresolved
        }
        return .group(groupPath(for: path, from: fact.file))
    }

    /// Forgets every extension group and unresolved extension. A module
    /// type registered under a group's key since (`extension Celsius {
    /// enum Scale }` beside `extension Celsius.Scale`) stays.
    private func clearGroups() {
        for key in extensionGroups.values where entries[key]?.kind == .extensionGroup {
            entries[key] = nil
        }
        extensionGroups = [:]
        unresolvedExtensions = []
    }

    /// Adds one extension to its group, or to the unresolved extensions.
    private func register(_ fact: ExtensionDeclFact, at placement: GroupPlacement) {
        guard case .group(let path) = placement else {
            unresolvedExtensions.append(fact)
            return
        }
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
}
