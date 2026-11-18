//
//  GroupPlacement.swift
//  SwiftCodeMetrics
//
//  Where an extension the module's types do not take goes (Spec §2.2).
//

/// An extension's place once extension groups are registered.
enum GroupPlacement: Equatable {
    /// The extension group keyed by this path.
    case group([String])
    /// Its path names a module type, through a group's typealias perhaps.
    case module(TypeKey)
    /// An unresolved extension: a module type with no such nested type.
    case unresolved

    /// The module type, for `.module`.
    var moduleKey: TypeKey? {
        if case .module(let key) = self {
            return key
        }
        return nil
    }
}
