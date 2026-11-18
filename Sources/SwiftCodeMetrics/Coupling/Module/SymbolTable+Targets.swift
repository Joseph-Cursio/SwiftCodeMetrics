//
//  SymbolTable+Targets.swift
//  SwiftCodeMetrics
//
//  Where an extension, a group's records and a type's own declaration
//  resolve to while the table is built (Spec §2.2, §7.3).
//

extension SymbolTable {
    /// The extension group a written path names from `file`: the key its
    /// extension registers under, so a file-private `typealias Num = Double`
    /// in one file and `= Int` in another name different groups, and
    /// `extension Swift.Result` next to a private `Result` keeps its own.
    func groupKey(for path: [String], from file: String) -> TypeKey? {
        extensionGroups[groupPath(for: path, from: file)]
    }

    /// Where a type's own declaration resolves names from.
    func declarationContext(of key: TypeKey) -> ResolutionContext {
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

    /// The module type an extension extends, if the table has it yet.
    func target(of fact: ExtensionDeclFact) -> TypeKey? {
        type(atPath: fact.extended.extensionPath(in: module), from: fact.file, localOwners: [])
    }

    /// The module type a path names from `file`, never an extension group.
    func moduleType(atPath path: [String], from file: String) -> TypeKey? {
        type(atPath: path, from: file, localOwners: []).flatMap { key in
            entries[key]?.kind == .extensionGroup ? nil : key
        }
    }

    /// The module type an extension extends, never an extension group.
    func moduleTarget(of fact: ExtensionDeclFact) -> TypeKey? {
        moduleType(atPath: fact.extended.extensionPath(in: module), from: fact.file)
    }

    /// Where a merged extension belongs once the table is complete: its
    /// module type; nil when its path now names something else, a group or
    /// a missing nested type of a module type included; or where it is
    /// when the path no longer resolves at all.
    func settledTarget(_ entry: MergedExtension) -> TypeKey? {
        if let key = moduleTarget(of: entry.fact) {
            return key
        }
        let path = entry.fact.extended.extensionPath(in: module)
        let resolution = resolve(
            SpelledType(components: path, moduleSelector: nil),
            from: qualifierContext(file: entry.fact.file)
        )
        let isGone = resolution != .unresolved || isMissingNestedType(path, from: entry.fact.file)
        return isGone ? nil : entry.key
    }
}
