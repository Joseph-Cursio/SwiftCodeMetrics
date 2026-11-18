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

    /// The path an extension of this name is keyed by in `module`: another
    /// module's selector becomes a leading component, so `extension
    /// Swift::Result` keys like `extension Swift.Result`, and the module's
    /// own selector drops, so `extension Shop::Item` in Shop is `Item` even
    /// when Shop declares a type named `Shop`.
    func extensionPath(in module: String) -> [String] {
        guard let selector = moduleSelector, selector != module else {
            return components
        }
        return [selector] + components
    }
}
