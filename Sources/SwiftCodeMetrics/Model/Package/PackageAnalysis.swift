//
//  PackageAnalysis.swift
//  SwiftCodeMetrics
//
//  The module level of a scan (Spec §10, §13.5).
//

/// Module coupling and module edges over every module of a scan.
public struct PackageAnalysis: Sendable, Codable, Hashable {
    /// One result per module, in input order.
    public var modules: [ModuleCoupling]
    /// One edge per `import` declaration in the scanned modules.
    public var moduleEdges: [ModuleDependency]
    /// The versions.
    public var version: MetricsVersion
}
