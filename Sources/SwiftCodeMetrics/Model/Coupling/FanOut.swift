//
//  FanOut.swift
//  SwiftCodeMetrics
//
//  Distinct callees of one function (Spec §8.1).
//

/// Fan-out and its separate counts.
public struct FanOut: Sendable, Codable, Hashable {
    /// Distinct keys, excluding implicit-member and chained ones.
    public var fanOut: Int
    /// Distinct keys whose receiver is `.`.
    public var fanOutImplicitMember: Int
    /// Distinct keys whose receiver is a call result.
    public var fanOutChained: Int
    /// Distinct keys per receiver kind.
    public var byReceiver: [ReceiverKind: Int]
    /// Distinct base names among the keys `fanOut` counts.
    public var distinctBaseNames: Int
    /// Freestanding macro expansions in the body.
    public var macroExpansionCount: Int
    /// One item per distinct key.
    public var calls: [CallKeyItem]
}
