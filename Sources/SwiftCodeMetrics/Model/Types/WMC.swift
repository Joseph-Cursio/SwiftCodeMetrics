//
//  WMC.swift
//  SwiftCodeMetrics
//
//  Weighted methods per class (Spec §9.2).
//

/// Summed complexity of a type's functions.
public struct WMC: Sendable, Codable, Hashable {
    /// The sum of cognitive complexity.
    public var cognitive: Int
    /// The sum of decision counts.
    public var decisions: Int
    /// Whether the sums run over a protocol's default implementations (`wmcDefaults`).
    public var isDefaults: Bool
}
