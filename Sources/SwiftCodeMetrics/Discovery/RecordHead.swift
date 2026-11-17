//
//  RecordHead.swift
//  SwiftCodeMetrics
//
//  The identity half of a new record: what its key and name are built from.
//

import SwiftSyntax

/// The declaration facts of a new record.
struct RecordHead {
    /// The kind of body.
    let kind: FunctionKind
    /// The readable name.
    let name: String
    /// The declaration part of the key.
    let declaration: String
    /// Whether the declaration is `private` or `fileprivate`.
    let isFileScoped: Bool
    /// The node whose span is the record's range.
    let node: Syntax
}
