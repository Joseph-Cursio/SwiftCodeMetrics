//
//  ModuleDependency.swift
//  SwiftCodeMetrics
//
//  One import between scanned modules (Spec §10.1).
//

/// An `import` declaration, as a module edge.
public struct ModuleDependency: Sendable, Codable, Hashable {
    /// The importing module.
    public var source: String
    /// The imported module.
    public var target: String
    /// Whether the import is `@_exported`.
    public var viaExported: Bool
    /// The enclosing `#if` condition, if any.
    public var condition: String?
    /// Where the edge came from.
    public var provenance: ModuleDependencyProvenance

    /// Creates an edge.
    public init(
        source: String,
        target: String,
        viaExported: Bool,
        condition: String?,
        provenance: ModuleDependencyProvenance
    ) {
        self.source = source
        self.target = target
        self.viaExported = viaExported
        self.condition = condition
        self.provenance = provenance
    }
}
