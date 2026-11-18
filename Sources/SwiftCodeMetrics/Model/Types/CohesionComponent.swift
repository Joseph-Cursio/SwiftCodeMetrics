//
//  CohesionComponent.swift
//  SwiftCodeMetrics
//
//  One connected group of members (Spec §9.3).
//

/// A counted component of the cohesion graph.
public struct CohesionComponent: Sendable, Codable, Hashable {
    /// Its members.
    public var members: [MemberKey]
    /// The attributes its members touch.
    public var attributes: [String]
    /// The extensions its members are declared in.
    public var extensions: [ExtensionFact]
    /// Whether some member is declared in the type's own declaration.
    public var includesPrimaryDeclaration: Bool
}
