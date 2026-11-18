//
//  SwiftCodeMetrics.swift
//  SwiftCodeMetrics
//
//  The library's entry points (Spec §13.1): complexity for one declaration
//  or file, and function-level coupling for a whole module.
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

    // MARK: Type level: every file of one module

    /// Runs the file pass on every file, in parallel, then the module pass (Spec §7.1),
    /// finalising each function's fan-out, common coupling, parameter counts
    /// and type references.
    public static func analyzeModule(
        _ module: ModuleInput,
        options: MetricsOptions = .init(),
        platformTable: PlatformTable = .bundled
    ) -> ModuleAnalysis {
        let files = FilePasses.run(module.files, module: module.name, options: options)
        return analyzeModule(
            name: module.name,
            isTest: module.isTest,
            files: files,
            options: options,
            platformTable: platformTable
        )
    }

    /// Pass 1 alone: per file, safe to run in parallel, and cacheable.
    /// Complexity is final here; coupling waits for the module pass.
    public static func analyzeFile(
        _ file: SourceFileInput,
        module: String,
        options: MetricsOptions = .init()
    ) -> FileAnalysis {
        let collector = FunctionCollector(context: CollectorContext(
            module: module,
            file: file.path,
            converter: SourceLocationConverter(fileName: file.path, tree: file.tree),
            options: options,
            includesTopLevelCode: true
        ))
        collector.walk(file.tree)
        let ordered = RecordOrdering.ordered(collector.drafts)
        return FileAnalysis(
            path: file.path,
            functions: ordered.records,
            rawReferences: RawReferences(functions: ordered.raw),
            declarations: collector.declarations,
            imports: collector.imports,
            version: version,
            options: options
        )
    }

    /// Pass 2 over file passes the caller already has: the `FileAnalysis` of
    /// every file in the module, made with the same options and version.
    public static func analyzeModule(
        name: String,
        isTest: Bool,
        files: [FileAnalysis],
        options: MetricsOptions = .init(),
        platformTable: PlatformTable = .bundled
    ) -> ModuleAnalysis {
        ModulePass.run(module: name, isTest: isTest, files: files, options: options, platform: platformTable)
    }

    // MARK: Module level: every module of the scan

    /// Pass 3 (Spec §10): module edges, and each module's Ce, Ca and
    /// instability over the scanned modules. Needs every `ModuleAnalysis`
    /// in the scan.
    public static func analyzePackage(_ modules: [ModuleAnalysis]) -> PackageAnalysis {
        PackagePass.run(modules)
    }
}
