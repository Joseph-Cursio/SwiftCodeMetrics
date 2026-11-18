//
//  ModulePass.swift
//  SwiftCodeMetrics
//
//  Pass 2 (Spec §7.1): builds the symbol table from every file pass and
//  finalises each function's coupling.
//

/// Runs the module pass.
enum ModulePass {
    /// The module analysis of `files`.
    static func run(
        module: String,
        isTest: Bool,
        files: [FileAnalysis],
        options: MetricsOptions,
        platform: PlatformTable
    ) -> ModuleAnalysis {
        let table = SymbolTable(module: module, files: files, platform: platform)
        var functions: [FunctionRecord] = []
        var facts: [RecordFacts?] = []
        for file in files {
            let offset = functions.count
            for (index, record) in file.functions.enumerated() {
                let raw = index < file.rawReferences.functions.count ? file.rawReferences.functions[index] : nil
                guard let raw else {
                    functions.append(record.moved(by: offset))
                    facts.append(nil)
                    continue
                }
                let resolver = FunctionResolver(table: table, raw: raw, imports: file.imports, options: options)
                functions.append(record.moved(by: offset).withCoupling(
                    parameters: resolver.parameterCounts(),
                    fanOut: resolver.fanOut(),
                    commonCoupling: resolver.commonCoupling(),
                    typeReferences: resolver.typeReferences()
                ))
                facts.append(resolver.currentType.map { owner in
                    RecordFacts(
                        owner: owner,
                        file: raw.context.file,
                        isTypeLevel: raw.context.isTypeLevel,
                        references: resolver.selfReferences()
                    )
                })
            }
        }
        let types = TypePass(
            table: table,
            functions: functions,
            facts: facts,
            importsByFile: Dictionary(files.map { ($0.path, $0.imports) }) { first, _ in first },
            fileOrder: Dictionary(files.enumerated().map { ($1.path, $0) }) { first, _ in first },
            options: options
        ).run()
        return ModuleAnalysis(
            module: module,
            isTest: isTest,
            functions: functions,
            types: types.types,
            typeEdges: types.edges,
            typeCycles: types.cycles,
            unresolvedExtensions: types.unresolvedExtensions,
            imports: files.flatMap(\.imports),
            version: MetricsVersion.current.using(platformTable: platform.sdkVersion),
            options: options
        )
    }
}
