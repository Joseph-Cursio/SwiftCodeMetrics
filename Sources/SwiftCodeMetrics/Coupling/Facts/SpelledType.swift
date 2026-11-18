//
//  SpelledType.swift
//  SwiftCodeMetrics
//
//  A type name as written: its dotted components with generic arguments
//  stripped and sugar mapped (`[Int]` is `Array`), plus any `Module::` selector.
//

/// A type name before resolution.
struct SpelledType: Codable, Hashable {
    /// The name components: `["Shop", "Item"]`.
    var components: [String]
    /// The module of a `Module::Name` selector.
    var moduleSelector: String?

    /// The components joined with dots.
    var spelling: String {
        components.joined(separator: ".")
    }

    /// The path an extension of this name is keyed by: a `Module::` selector
    /// becomes a leading component, so `extension Swift::Result` keys like
    /// `extension Swift.Result`.
    var extensionPath: [String] {
        (moduleSelector.map { [$0] } ?? []) + components
    }
}
