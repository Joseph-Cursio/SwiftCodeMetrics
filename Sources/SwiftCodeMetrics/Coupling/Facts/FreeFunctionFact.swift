//
//  FreeFunctionFact.swift
//  SwiftCodeMetrics
//
//  One top-level function, with the visibility a file-private one has.
//

/// A module free function.
struct FreeFunctionFact: Codable, Hashable {
    /// Its name, without backticks.
    var name: String
    /// The declaring file.
    var file: String
    /// Whether it is `private` or `fileprivate`.
    var isFileScoped: Bool
}
