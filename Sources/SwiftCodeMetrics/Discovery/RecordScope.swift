//
//  RecordScope.swift
//  SwiftCodeMetrics
//
//  A record, or a key context such as a stored property's initial value
//  with no record of its own, on the collector's scope stack.
//

import SwiftSyntax

/// A record or key context scope.
struct RecordScope {
    /// The node that opened it.
    let owner: SyntaxIdentifier
    /// The full key, which prefixes the keys of declarations inside it.
    let fullKey: String
    /// How many `#if` conditions were open when it opened.
    let conditionDepth: Int
    /// The record's draft index; nil for a context that is not a record.
    let draftIndex: Int?
    /// Generic parameters the record's declaration makes visible.
    let genericParameters: [String]
}
