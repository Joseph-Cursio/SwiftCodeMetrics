//
//  TypeScope.swift
//  SwiftCodeMetrics
//
//  A type or extension on the collector's scope stack.
//

import SwiftSyntax

/// A type or extension scope.
struct TypeScope {
    /// The declaration that opened it.
    let owner: SyntaxIdentifier
    /// The key path component: the name, or the extended type and its `where` clause.
    let pathComponent: String
    /// Whether the type is `private` or `fileprivate`, directly or by nesting.
    let isFileScoped: Bool
    /// The lexical path components it adds: its name, or an extension's extended type.
    let nominal: [String]
    /// Whether it is an extension.
    let isExtension: Bool
    /// Generic parameters and associated types it makes visible.
    let genericParameters: [String]
}
