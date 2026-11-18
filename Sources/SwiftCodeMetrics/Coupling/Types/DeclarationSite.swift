//
//  DeclarationSite.swift
//  SwiftCodeMetrics
//
//  Where a type's declaration-level names are written: its own declaration
//  or one of its extensions (Spec §9.4 edge kinds).
//

/// The type a declaration belongs to, and whether it is an extension.
struct DeclarationSite {
    /// The type the names couple from.
    let owner: TypeEntry
    /// Whether the names are written on an extension, where every
    /// inheritance entry is a protocol.
    let isExtension: Bool
    /// Where the inheritance clause's names resolve from.
    let clauseResolver: FunctionResolver
}
