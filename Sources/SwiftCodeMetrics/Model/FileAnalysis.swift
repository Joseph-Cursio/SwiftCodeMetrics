//
//  FileAnalysis.swift
//  SwiftCodeMetrics
//
//  The file pass (Spec §7.1, §13.5): complexity is final; coupling waits
//  for the module pass. Codable, so callers can cache it by content hash.
//

/// One file's pass-1 result.
public struct FileAnalysis: Sendable, Codable, Hashable {
    /// The file path.
    public var path: String
    /// The records, with final complexity and nil coupling.
    public var functions: [FunctionRecord]
    /// Call sites, names and type names with their lookup results.
    public var rawReferences: RawReferences
    /// Types, extensions, members, globals and typealiases.
    public var declarations: DeclarationFacts
    /// The file's imports.
    public var imports: [ImportFact]
    /// The versions that produced it.
    public var version: MetricsVersion
    /// The options that produced it.
    public var options: MetricsOptions
}
