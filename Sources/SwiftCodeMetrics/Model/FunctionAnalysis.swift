//
//  FunctionAnalysis.swift
//  SwiftCodeMetrics
//
//  The result of the function-level entry points (Spec §13.2).
//

/// Every function record of one declaration or one file.
public struct FunctionAnalysis: Sendable, Codable, Hashable {
    /// The versions that produced these values.
    public var version: MetricsVersion
    /// The options that produced these values.
    public var options: MetricsOptions
    /// The records, in record order (Spec §13.1).
    public var functions: [FunctionRecord]
}
