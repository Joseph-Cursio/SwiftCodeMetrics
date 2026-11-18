//
//  ModuleDependencyProvenance.swift
//  SwiftCodeMetrics
//
//  Where a module edge came from (Spec §10.1).
//

/// The source of a module edge.
public enum ModuleDependencyProvenance: String, Sendable, Codable, Hashable {
    /// An `import` declaration.
    case `import`
    /// An index store.
    case index
}
