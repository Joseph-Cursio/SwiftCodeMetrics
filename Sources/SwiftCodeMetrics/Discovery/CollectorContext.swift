//
//  CollectorContext.swift
//  SwiftCodeMetrics
//
//  What the collector knows about the file it walks.
//

import SwiftSyntax

/// The settings of one collection.
struct CollectorContext {
    /// The module name, the first key part.
    let module: String
    /// The file, added to keys of `private` and `fileprivate` declarations.
    let file: String?
    /// Converts offsets to lines; nil when locations are unknown.
    let converter: SourceLocationConverter?
    /// The options.
    let options: MetricsOptions
    /// Whether to add a `.topLevelCode` record (file form only).
    let includesTopLevelCode: Bool
}
