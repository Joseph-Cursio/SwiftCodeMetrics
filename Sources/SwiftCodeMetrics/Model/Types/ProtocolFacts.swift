//
//  ProtocolFacts.swift
//  SwiftCodeMetrics
//
//  Requirement and default counts of a protocol (Spec §9.1, §9.5).
//

/// A protocol's requirements, defaults and conformers.
public struct ProtocolFacts: Sendable, Codable, Hashable {
    /// Functions, properties, initialisers, subscripts and associated types required.
    public var requirementCount: Int
    /// Members of the protocol's extensions.
    public var defaultImplementationCount: Int
    /// Extension members whose base name and labels match a requirement.
    public var defaultsForRequirements: Int
    /// Extension members that match no requirement.
    public var extensionOnlyMembers: Int
    /// Non-protocol module types that conform, directly or through a refining protocol.
    public var conformerCount: Int
}
