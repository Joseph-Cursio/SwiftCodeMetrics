//
//  PackagePass.swift
//  SwiftCodeMetrics
//
//  The module level (Spec §10.1, §10.2): module edges from imports, and
//  each module's Ce, Ca and instability over the scanned modules.
//

/// Computes module coupling over a scan.
enum PackagePass {
    /// Modules every file imports implicitly.
    private static let implicitModules: Set<String> = ["Swift", "_Concurrency", "_StringProcessing"]

    /// The package analysis of `modules`.
    static func run(_ modules: [ModuleAnalysis]) -> PackageAnalysis {
        let scanned = Set(modules.map(\.module))
        let edges = modules.flatMap { module in
            module.imports.map { fact in
                ModuleDependency(
                    source: module.module,
                    target: fact.module,
                    viaExported: fact.isExported,
                    condition: fact.condition,
                    provenance: .import
                )
            }
        }
        var imports: [String: Set<String>] = [:]
        var reexports: [String: Set<String>] = [:]
        for module in modules {
            let own = module.imports.map(\.module).filter { name in
                name != module.module && implicitModules.contains(name) == false
            }
            imports[module.module, default: []].formUnion(own)
            reexports[module.module, default: []].formUnion(
                module.imports.filter { $0.isExported && scanned.contains($0.module) }.map(\.module)
            )
        }
        let tests = Set(modules.filter(\.isTest).map(\.module))
        let results = modules.map { module in
            let all = imports[module.module] ?? []
            let package = all.intersection(scanned)
            let withReexports = closure(of: package, through: reexports).subtracting([module.module])
            let importers = modules.filter { other in
                other.module != module.module && (imports[other.module] ?? []).contains(module.module)
            }
            let reaching = modules.filter { other in
                let direct = (imports[other.module] ?? []).intersection(scanned)
                return other.module != module.module && closure(of: direct, through: reexports).contains(module.module)
            }
            let direct = importers.filter { tests.contains($0.module) == false }.count
            return ModuleCoupling(
                module: module.module,
                isTest: module.isTest,
                ceAll: all.count,
                cePackage: package.count,
                ceWithReexports: withReexports.count,
                caDirect: direct,
                caWithReexports: reaching.filter { tests.contains($0.module) == false }.count,
                caTests: importers.filter { tests.contains($0.module) }.count,
                instability: direct + package.count == 0 ? nil : Double(package.count) / Double(direct + package.count)
            )
        }
        let version = modules.first?.version ?? MetricsVersion.current
        return PackageAnalysis(modules: results, moduleEdges: edges, version: version)
    }

    /// `start` plus every module re-exported from it, transitively.
    private static func closure(of start: Set<String>, through reexports: [String: Set<String>]) -> Set<String> {
        var seen = start
        var pending = Array(start)
        while let next = pending.popLast() {
            for exported in reexports[next] ?? [] where seen.insert(exported).inserted {
                pending.append(exported)
            }
        }
        return seen
    }
}
