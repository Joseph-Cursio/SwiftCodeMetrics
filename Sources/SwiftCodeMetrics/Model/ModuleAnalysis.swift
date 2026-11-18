//
//  ModuleAnalysis.swift
//  SwiftCodeMetrics
//
//  The module pass (Spec §7.1, §13.5). v0.2 resolves function-level
//  coupling; type records, the type graph and unresolved extensions arrive
//  with v0.3.
//

/// One module's pass-2 result.
public struct ModuleAnalysis: Sendable, Codable, Hashable {
    /// The module name.
    public var module: String
    /// Whether it is a test target.
    public var isTest: Bool
    /// Every record of every file, in file order then record order, with
    /// coupling resolved.
    public var functions: [FunctionRecord]
    /// Every type and extension group, merged (Spec §9).
    public var types: [TypeResult]
    /// The `ce` edges between module types (Spec §10.3).
    public var typeEdges: [TypeCoupling]
    /// Strongly connected components of size at least 2 over every edge.
    public var typeCycles: [[TypeKey]]
    /// Extensions of missing nested types of module types (Spec §2.2).
    public var unresolvedExtensions: [ExtensionFact]
    /// Every import of every file.
    public var imports: [ImportFact]
    /// The versions, with `couplingDefinition` and `platformTable` set.
    public var version: MetricsVersion
    /// The options.
    public var options: MetricsOptions
}
