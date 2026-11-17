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
    /// Every import of every file.
    public var imports: [ImportFact]
    /// The versions, with `couplingDefinition` and `platformTable` set.
    public var version: MetricsVersion
    /// The options.
    public var options: MetricsOptions
}
