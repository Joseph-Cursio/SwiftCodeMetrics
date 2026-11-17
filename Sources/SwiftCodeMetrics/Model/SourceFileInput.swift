//
//  SourceFileInput.swift
//  SwiftCodeMetrics
//
//  A file the caller has already parsed. The library never reads files or
//  walks directories (Spec §1.4).
//

import SwiftSyntax

/// One parsed source file.
public struct SourceFileInput: Sendable {
    /// The path used in keys of `private` and `fileprivate` declarations.
    public var path: String
    /// The parsed tree, folded or not.
    public var tree: SourceFileSyntax

    /// Wraps a parsed file.
    public init(path: String, tree: SourceFileSyntax) {
        self.path = path
        self.tree = tree
    }
}
