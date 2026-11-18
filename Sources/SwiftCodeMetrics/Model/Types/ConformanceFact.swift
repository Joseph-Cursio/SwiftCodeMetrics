//
//  ConformanceFact.swift
//  SwiftCodeMetrics
//
//  One declared conformance (Spec §9.1).
//

/// A conformance as declared.
public struct ConformanceFact: Sendable, Codable, Hashable {
    /// The name as written, after unwrapping attributes and splitting `P & Q`.
    public var name: String
    /// The module protocol it resolves to, if any.
    public var target: TypeKey?
    /// Whether it is declared in a constrained extension.
    public var isConditional: Bool
}
