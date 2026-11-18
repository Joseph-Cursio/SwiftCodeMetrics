//
//  SpelledType.swift
//  SwiftCodeMetrics
//
//  A type name as written: its dotted components with generic arguments
//  stripped and sugar mapped (`[Int]` is `Array`), plus any `Module::` selector.
//

/// A type name before resolution.
struct SpelledType: Codable, Hashable {
    /// What ends a selector component in a path: `Swift::`.
    static let selectorMark = "::"

    /// The name components: `["Shop", "Item"]`.
    var components: [String]
    /// The module of a `Module::Name` selector.
    var moduleSelector: String?

    /// The components joined with dots.
    var spelling: String {
        components.joined(separator: ".")
    }

    /// Every selector as a leading `Module::` component, the module's own too.
    var lexicalPath: [String] {
        (moduleSelector.map { [$0 + Self.selectorMark] } ?? []) + components
    }

    /// The selector a path's leading `Module::` component names, if any.
    static func selector(of path: [String]) -> String? {
        guard let first = path.first, first.hasSuffix(selectorMark) else {
            return nil
        }
        return String(first.dropLast(selectorMark.count))
    }

    /// A path with its leading `Module::` component written as `Module`:
    /// `extension Swift::Result` keys its group like `extension Swift.Result`.
    static func dotted(_ path: [String]) -> [String] {
        guard let selector = selector(of: path) else {
            return path
        }
        return [selector] + path.dropFirst()
    }

    /// The path an extension of this name is written at in `module`: the
    /// module's own selector drops, so `extension Shop::Item` in Shop is
    /// `Item` even when Shop declares a type named `Shop`; another module's
    /// selector stays as a leading `Swift::` component, which resolution
    /// treats as a selector, so no module type named `Swift` shadows it.
    func extensionPath(in module: String) -> [String] {
        guard let selector = moduleSelector, selector != module else {
            return components
        }
        return [selector + Self.selectorMark] + components
    }
}
