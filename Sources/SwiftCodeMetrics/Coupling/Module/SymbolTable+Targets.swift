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
}
