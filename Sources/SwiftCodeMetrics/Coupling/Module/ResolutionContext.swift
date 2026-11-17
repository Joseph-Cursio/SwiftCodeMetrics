//
//  ResolutionContext.swift
//  SwiftCodeMetrics
//
//  Where a name is resolved from: the file, its imports, the enclosing
//  types and the visible generic parameters.
//

/// The position a type name is resolved from.
struct ResolutionContext {
    /// The file, for `private` types and imports.
    let file: String
    /// Modules a qualifier may name: this module, the platform modules and the file's imports.
    let knownModules: Set<String>
    /// Whether the file imports XCTest.
    let importsXCTest: Bool
    /// Whether the file imports Foundation or a module that re-exports it.
    let importsFoundation: Bool
    /// The current type, then each enclosing type.
    let chain: [TypeKey]
    /// Visible generic parameters and associated types.
    let genericParameters: Set<String>
    /// Records that own visible local types, nearest first.
    let localOwners: [MemberKey]
}
