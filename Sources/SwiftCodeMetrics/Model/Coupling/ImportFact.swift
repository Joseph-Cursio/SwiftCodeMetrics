//
//  ImportFact.swift
//  SwiftCodeMetrics
//
//  One `import` declaration (Spec §10.1).
//

/// An imported module.
public struct ImportFact: Sendable, Codable, Hashable {
    /// The module name: the first component of the import path.
    public var module: String
    /// Whether the import is `@_exported`.
    public var isExported: Bool
    /// The enclosing `#if` condition, if any.
    public var condition: String?
    /// The importing file.
    public var file: String
}
