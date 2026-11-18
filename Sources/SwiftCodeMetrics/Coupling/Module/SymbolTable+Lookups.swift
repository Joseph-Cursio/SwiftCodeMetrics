//
//  SymbolTable+Lookups.swift
//  SwiftCodeMetrics
//
//  Module-level value lookups: free functions and globals (Spec §7.2).
//

extension SymbolTable {
    /// Whether a free function named `name` is visible from `file`.
    func isFreeFunction(_ name: String, from file: String) -> Bool {
        freeFunctions[name]?.contains { $0.isFileScoped == false || $0.file == file } == true
    }

    /// The visible global named `name`, if any.
    func global(_ name: String, from file: String) -> GlobalFact? {
        // `let` in one `#if` clause and `var` in another is mutable (Spec §2.6).
        let visible = (globals[name] ?? []).filter { $0.isFileScoped == false || $0.file == file }
        return visible.first(where: \.isStoredVar) ?? visible.first
    }

    /// A context at file scope, for extension and lexical paths.
    func topLevelContext(file: String) -> ResolutionContext {
        ResolutionContext(
            file: file,
            knownModules: [module],
            importsXCTest: false,
            importsFoundation: false,
            chain: [],
            genericParameters: [],
            localOwners: []
        )
    }
}
