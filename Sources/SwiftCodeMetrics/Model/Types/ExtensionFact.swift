//
//  ExtensionFact.swift
//  SwiftCodeMetrics
//
//  One extension declaration (Spec §9.1, §13.5).
//

/// An extension, merged or unresolved.
public struct ExtensionFact: Sendable, Codable, Hashable {
    /// The declaring file.
    public var file: String
    /// The declaration's span.
    public var range: ByteRange
    /// The extended type as written: `SyncUpDetail.Destination.State`.
    public var extendedType: String
    /// The conformances it declares.
    public var conformances: [ConformanceFact]
    /// The canonical text of its generic `where` clause.
    public var whereClause: String?
}
