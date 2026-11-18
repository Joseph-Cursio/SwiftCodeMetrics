//
//  PackageExampleTests.swift
//  SwiftCodeMetricsTests
//
//  Spec §16 v0.3 golden tests for the module level: the §12.6 table, its
//  re-export variant, and the module edges of §10.1.
//

import SwiftCodeMetrics
import Testing

@Suite("Worked example: module coupling (Spec §12.6)")
struct PackageExampleTests {
    @Test("§12.6 the table: Ce, Ca and instability per module")
    func table() {
        let package = SwiftCodeMetrics.analyzePackage([
            module("Core", imports: "import Foundation"),
            module("Networking", imports: "import Foundation\nimport Core"),
            module("App", imports: "import SwiftUI\nimport Core\nimport Networking"),
            module("CoreTests", imports: "import Core\nimport XCTest", isTest: true)
        ])
        let rows = Dictionary(uniqueKeysWithValues: package.modules.map { ($0.module, $0) })

        #expect(row(rows["Core"]) == [1, 0, 0, 2, 2, 1])
        #expect(row(rows["Networking"]) == [2, 1, 1, 1, 1, 0])
        #expect(row(rows["App"]) == [3, 2, 2, 0, 0, 0])
        #expect(row(rows["CoreTests"]) == [2, 1, 1, 0, 0, 0])
        #expect(rows["Core"]?.instability == 0)
        #expect(rows["Networking"]?.instability == 0.5)
        #expect(rows["App"]?.instability == 1)
        #expect(rows["CoreTests"]?.instability == 1)
        #expect(package.moduleEdges.count == 8)
        #expect(package.moduleEdges.allSatisfy { $0.provenance == .import && $0.viaExported == false })
    }

    @Test("§12.6 an @_exported import reaches Feature through Networking")
    func reexports() {
        let package = SwiftCodeMetrics.analyzePackage([
            module("Core", imports: "import Foundation"),
            module("Networking", imports: "import Foundation\n@_exported import Core"),
            module("App", imports: "import SwiftUI\nimport Core\nimport Networking"),
            module("Feature", imports: "import Networking")
        ])
        let rows = Dictionary(uniqueKeysWithValues: package.modules.map { ($0.module, $0) })

        #expect(rows["App"]?.ceWithReexports == 2)
        #expect(rows["Feature"]?.cePackage == 1)
        #expect(rows["Feature"]?.ceWithReexports == 2)
        #expect(rows["Core"]?.caDirect == 2)
        #expect(rows["Core"]?.caWithReexports == 3)
        #expect(rows["Networking"]?.caDirect == 2)
        #expect(package.moduleEdges.filter(\.viaExported).map(\.target) == ["Core"])
    }

    @Test("instability is nil when a module neither imports nor is imported within the scan")
    func isolatedModule() {
        let package = SwiftCodeMetrics.analyzePackage([module("Alone", imports: "import Foundation")])

        #expect(package.modules.first?.instability == nil)
        #expect(package.modules.first?.ceAll == 1)
    }

    @Test("the condition of an import inside #if is kept on its edge (Spec §10.1)")
    func conditionalImport() {
        let package = SwiftCodeMetrics.analyzePackage([
            module("Core", imports: ""),
            module("App", imports: "#if canImport(Core)\nimport Core\n#endif")
        ])

        #expect(package.moduleEdges.map(\.condition) == ["canImport(Core)"])
    }

    /// ceAll, cePackage, ceWithReexports, caDirect, caWithReexports, caTests.
    private func row(_ coupling: ModuleCoupling?) -> [Int] {
        guard let coupling else {
            return []
        }
        return [
            coupling.ceAll, coupling.cePackage, coupling.ceWithReexports,
            coupling.caDirect, coupling.caWithReexports, coupling.caTests
        ]
    }

    private func module(_ name: String, imports: String, isTest: Bool = false) -> ModuleAnalysis {
        SwiftCodeMetrics.analyzeModule(Modules.input(name, [(name + "/File.swift", imports)], isTest: isTest))
    }
}
