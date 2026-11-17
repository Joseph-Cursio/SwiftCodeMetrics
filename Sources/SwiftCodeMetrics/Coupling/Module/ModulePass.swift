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
        for file in files {
            let offset = functions.count
            for (index, record) in file.functions.enumerated() {
                let raw = index < file.rawReferences.functions.count ? file.rawReferences.functions[index] : nil
                guard let raw else {
                    functions.append(record.moved(by: offset))
                    continue
                }
                let resolver = FunctionResolver(table: table, raw: raw, imports: file.imports, options: options)
                functions.append(record.moved(by: offset).withCoupling(
                    parameters: resolver.parameterCounts(),
                    fanOut: resolver.fanOut(),
                    commonCoupling: resolver.commonCoupling(),
                    typeReferences: resolver.typeReferences()
                ))
            }
        }
        return ModuleAnalysis(
            module: module,
            isTest: isTest,
            functions: functions,
            imports: files.flatMap(\.imports),
            version: MetricsVersion.current.using(platformTable: platform.sdkVersion),
            options: options
        )
    }
}
