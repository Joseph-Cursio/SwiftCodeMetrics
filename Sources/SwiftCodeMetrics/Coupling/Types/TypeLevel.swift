//
//  TypeLevel.swift
//  SwiftCodeMetrics
//
//  The type-level results of a module pass.
//

/// Types, edges, cycles and unresolved extensions of one module.
struct TypeLevel {
    /// Every type and extension group.
    let types: [TypeResult]
    /// The `ce` edges.
    let edges: [TypeCoupling]
    /// Strongly connected components of size at least 2.
    let cycles: [[TypeKey]]
    /// Extensions of missing nested types.
    let unresolvedExtensions: [ExtensionFact]
}
