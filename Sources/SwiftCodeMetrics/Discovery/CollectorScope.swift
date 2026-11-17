//
//  CollectorScope.swift
//  SwiftCodeMetrics
//
//  One open scope while collecting records: a type, which adds to the key
//  path, or a record or key context, which becomes the key prefix.
//

import SwiftSyntax

/// An open scope.
enum CollectorScope {
    /// A record, or a context that prefixes keys without being a record.
    case record(RecordScope)
    /// A type or extension.
    case type(TypeScope)

    /// The node that opened the scope.
    var owner: SyntaxIdentifier {
        switch self {
        case .record(let record):
            record.owner

        case .type(let type):
            type.owner
        }
    }
}
