//
//  MetricsOptions.swift
//  SwiftCodeMetrics
//
//  Options that change values. They are stored with every result, so a
//  consumer can tell a change of options from a change of code.
//

/// Options for every metric family. v0.1 has complexity options only.
public struct MetricsOptions: Sendable, Hashable, Codable {
    /// Options for Part A.
    public var complexity = ComplexityOptions()

    /// The defaults.
    public init() {
        // Every property has a default.
    }
}
