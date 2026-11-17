//
//  SwiftCodeMetrics.swift
//  SwiftCodeMetrics
//
//  The library's entry points (Spec §13.1). v0.1 has the function level:
//  complexity for one declaration or one file.
//

import SwiftSyntax

/// Complexity, coupling and cohesion measures for Swift source, from syntax alone.
public enum SwiftCodeMetrics {
    /// Library and definition versions. Every result carries a copy.
    public static let version = MetricsVersion.current

    /// Scores every function in `declaration`: its own function(s) first, then
    /// nested functions, local variables' accessors, local-type members and
    /// local-type property initialisers, in record order (Spec §13.1). A type
    /// or extension gives a record per member, recursively, and a
    /// `.propertyInitializer` record for each stored property whose initial
    /// value has non-zero C or D.
    public static func functionMetrics(
        of declaration: some DeclSyntaxProtocol,
        module: String = "",
        file: String? = nil,
        options: MetricsOptions = .init(),
        locations: SourceLocationConverter? = nil
    ) -> FunctionAnalysis {
        let collector = FunctionCollector(context: CollectorContext(
            module: module,
            file: file,
            converter: locations,
            options: options,
            includesTopLevelCode: false
        ))
        collector.seedScopes(around: Syntax(declaration))
        collector.walk(declaration)
        return FunctionAnalysis(
            version: version,
            options: options,
            functions: RecordOrdering.records(from: collector.drafts)
        )
    }

    /// The same for a whole file, adding a `.topLevelCode` record when the
    /// file has top-level statements, and `.propertyInitializer` records for
    /// globals. Line and column ranges are always filled.
    public static func functionMetrics(
        of file: SourceFileInput,
        module: String = "",
        options: MetricsOptions = .init()
    ) -> FunctionAnalysis {
        let collector = FunctionCollector(context: CollectorContext(
            module: module,
            file: file.path,
            converter: SourceLocationConverter(fileName: file.path, tree: file.tree),
            options: options,
            includesTopLevelCode: true
        ))
        collector.walk(file.tree)
        return FunctionAnalysis(
            version: version,
            options: options,
            functions: RecordOrdering.records(from: collector.drafts)
        )
    }
}
