//
//  MetricsOptions.swift
//  SwiftCodeMetrics
//
//  Options that change values. They are stored with every result, so a
//  consumer can tell a change of options from a change of code. Decoding
//  fills options a stored value lacks with their defaults.
//

/// Options for every metric family.
public struct MetricsOptions: Sendable, Hashable, Codable {
    private enum CodingKeys: String, CodingKey {
        case complexity
        case diagnosticFreeFunctions
    }

    /// Options for Part A.
    public var complexity = ComplexityOptions()
    /// Free functions left out of fan-out when the module does not declare them (Spec §8.1).
    public var diagnosticFreeFunctions: Set<String> = [
        "assert", "assertionFailure", "debugPrint", "dump", "fatalError", "precondition",
        "preconditionFailure", "print"
    ]

    /// The defaults.
    public init() {
        // Every property has a default.
    }

    /// Decodes options, defaulting any that are missing.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Self()
        complexity = try container.decodeIfPresent(ComplexityOptions.self, forKey: .complexity) ?? defaults.complexity
        diagnosticFreeFunctions = try container.decodeIfPresent(Set<String>.self, forKey: .diagnosticFreeFunctions)
            ?? defaults.diagnosticFreeFunctions
    }

    /// Encodes the function set sorted, so stored options are stable.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(complexity, forKey: .complexity)
        try container.encode(diagnosticFreeFunctions.sorted(), forKey: .diagnosticFreeFunctions)
    }
}
