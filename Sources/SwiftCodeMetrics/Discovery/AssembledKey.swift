//
//  AssembledKey.swift
//  SwiftCodeMetrics
//
//  A key built from the open scopes, before nested repeats are numbered.
//

/// The parts of a freshly built key.
struct AssembledKey {
    /// The key text after `module::`, without the record's own file suffix.
    let text: String
    /// The file suffix, for a `private` or `fileprivate` declaration with no prefix.
    let file: String?
    /// Whether a record or context prefixes the key.
    let isNested: Bool
}
