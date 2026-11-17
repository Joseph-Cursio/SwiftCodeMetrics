//
//  GlobalFact.swift
//  SwiftCodeMetrics
//
//  One top-level variable (Spec §8.2).
//

/// A module global.
struct GlobalFact: Codable, Hashable {
    /// Its name.
    var name: String
    /// A stored `var`.
    var isStoredVar: Bool
    /// The declaring file.
    var file: String
    /// Whether it is `private` or `fileprivate`.
    var isFileScoped: Bool
}
