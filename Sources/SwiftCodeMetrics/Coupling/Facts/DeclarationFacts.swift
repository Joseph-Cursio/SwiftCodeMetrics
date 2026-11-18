//
//  DeclarationFacts.swift
//  SwiftCodeMetrics
//
//  The declarations of one file: what the module pass merges into the
//  symbol table (Spec §7.1).
//

/// One file's declarations. Opaque to callers; stored inside `FileAnalysis`.
public struct DeclarationFacts: Sendable, Codable, Hashable {
    /// Types, local ones included.
    var types: [TypeFact] = []
    /// Extensions.
    var extensions: [ExtensionDeclFact] = []
    /// Top-level variables.
    var globals: [GlobalFact] = []
    /// Top-level function names.
    var freeFunctions: [FreeFunctionFact] = []
    /// Top-level typealiases.
    var typealiases: [TypealiasFact] = []
    /// Names of `macro` declarations (Spec §9.1 `hasKnownAttachedMacro`).
    var macroNames: [String] = []
}
