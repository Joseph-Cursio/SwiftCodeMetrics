//
//  MetricsVersion.swift
//  SwiftCodeMetrics
//
//  Which library release and which metric definitions produced a result
//  (Spec §13.4). A definition version changes whenever a value can change.
//

/// The library release and definition versions behind a result.
public struct MetricsVersion: Sendable, Codable, Hashable {
    /// This build's versions.
    public static let current = Self(
        library: "0.1.0",
        swiftSyntax: "603.0.2",
        complexityDefinition: "complexity-1",
        couplingDefinition: nil,
        platformTable: nil,
        swiftLintReference: "0.65.1"
    )

    /// The package release, such as `0.1.0`.
    public let library: String
    /// The swift-syntax release the library is built against.
    public let swiftSyntax: String
    /// The complexity definition version (Spec Q4).
    public let complexityDefinition: String
    /// The coupling definition version; nil before v0.2.
    public let couplingDefinition: String?
    /// The SDK version the platform table came from; nil when no table was used.
    public let platformTable: String?
    /// The SwiftLint release the SwiftLint-compatible count was checked against.
    public let swiftLintReference: String
}
