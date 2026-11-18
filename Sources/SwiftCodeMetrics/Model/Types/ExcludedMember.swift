//
//  ExcludedMember.swift
//  SwiftCodeMetrics
//
//  A member left out of the cohesion graph (Spec §9.3).
//

/// A member that is not a node, with the reason.
public struct ExcludedMember: Sendable, Codable, Hashable {
    /// The member.
    public var key: MemberKey
    /// Why it is excluded.
    public var reason: ExclusionReason
}
