//
//  MergedExtension.swift
//  SwiftCodeMetrics
//

/// An extension the symbol table merged into a module type, with its place
/// in source order so settling can hand it back to the groups in order.
struct MergedExtension: Equatable {
    /// Its index among the module's extensions, in source order.
    let index: Int
    /// The extension.
    let fact: ExtensionDeclFact
    /// The module type it is merged into.
    let key: TypeKey
}
