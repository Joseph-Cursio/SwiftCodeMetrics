//
//  ExtensionDeclFact.swift
//  SwiftCodeMetrics
//
//  One extension, before it is merged into its type.
//

/// A declared extension.
struct ExtensionDeclFact: Codable, Hashable {
    /// The extended type as written.
    var extended: SpelledType
    /// Its members.
    var members: [MemberFact]
    /// Its member typealiases.
    var typealiases: [TypealiasFact]
    /// The declaring file.
    var file: String
}
