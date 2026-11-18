//
//  ModulePassTests.swift
//  SwiftCodeMetricsTests
//
//  Spec §16 v0.2: the platform table's classifications, the module pass
//  over cached file passes, and the module pass's speed.
//

import Foundation
import SwiftCodeMetrics
import SwiftParser
import Testing

@Suite("Module pass (Spec §7, §16)")
struct ModulePassTests {
    private static let collections = FileManager.default.homeDirectoryForCurrentUser.path
        + "/GitHub_projects/swift-collections/Sources"

    @Test("the bundled platform table classifies the names §16 lists")
    func platformTable() {
        let table = PlatformTable.bundled

        #expect(table.sdkVersion == "27.2")
        for name in ["JSONDecoder", "DispatchQueue", "Decimal", "TimeInterval"] {
            #expect(table.types.contains(name), "\(name)")
        }
        #expect(table.freeFunctions.contains("NSDecimalRound"))
        #expect(table.freeFunctions.contains("NSLog"))
        #expect(table.freeFunctions.contains("XCTAssertEqual") == false)
        #expect(table.xcTestFreeFunctions.contains("XCTAssertEqual"))
    }

    @Test("XCTAssertEqual is a platform free function only in files that import XCTest")
    func xcTestScope() {
        let analysis = Modules.analysis("Tests", [
            ("A.swift", "import XCTest\nfunc a() { XCTAssertEqual(1, 1) }"),
            (
                "B.swift",
                "import Foundation\nfunc b() { XCTAssertEqual(1, 1); NSLog(\"x\"); "
                    + "_ = DispatchQueue(label: \"q\") }"
            )
        ])

        #expect(Modules.headline(Modules.record("a()", in: analysis)) == ["free.XCTAssertEqual(_:_:)"])
        #expect(Modules.headline(Modules.record("b()", in: analysis)) == [
            "DispatchQueue.init(label:)", "XCTAssertEqual.init(_:_:)", "free.NSLog(_:)"
        ])
        #expect(analysis.version.platformTable == "27.2")
        #expect(analysis.version.couplingDefinition == "coupling-2")
    }

    @Test("functions, statics and globals the module declares win over the platform table")
    func moduleShadowsPlatform() {
        let analysis = Modules.analysis("Lib", [
            (
                "A.swift",
                "struct Date { static let zero = Date() }\nfunc print(_ x: Any) {}\n"
                    + "func use() { print(Date.zero); _ = Date() }"
            )
        ])
        let use = Modules.record("use()", in: analysis)

        #expect(Modules.headline(use) == ["Date.init()", "free.print(_:)"])
        #expect(use?.typeReferences.first?.bucket == .module)
        #expect(use?.commonCoupling?.statics == ["Date.zero"])
        #expect(use?.commonCoupling?.singletons.isEmpty == true)
    }

    @Test("closure parameters are counted through module typealiases")
    func closureParameters() {
        let analysis = Modules.analysis("Lib", [
            ("A.swift", """
            typealias Handler = (Int) -> Void
            func run(_ a: Handler, _ b: @escaping () -> Void, _ c: (() -> Void)?, \
            _ d: inout Int, _ e: Int = 0, _ f: Int...) {}
            """)
        ])
        let counts = Modules.record("run(_:_:_:_:_:_:)", in: analysis)?.parameters

        #expect(counts?.parameterCount == 6)
        #expect(counts?.defaultedParameterCount == 1)
        #expect(counts?.variadicParameterCount == 1)
        #expect(counts?.inoutParameterCount == 1)
        #expect(counts?.closureParameterCount == 3)
        #expect(counts?.escapingClosureParameterCount == 2)
    }

    @Test("the module pass over decoded file passes equals the module pass over trees")
    func caching() throws {
        let sources = CouplingSources.shop + CouplingSources.app.map { ($0.path, $0.source) }
        let input = Modules.input("App", sources)
        let direct = SwiftCodeMetrics.analyzeModule(input)
        let decoded = try input.files.map { file in
            let pass = SwiftCodeMetrics.analyzeFile(file, module: "App")
            return try JSONDecoder().decode(FileAnalysis.self, from: JSONEncoder().encode(pass))
        }
        let cached = SwiftCodeMetrics.analyzeModule(name: "App", isTest: false, files: decoded)

        #expect(cached == direct)
        #expect(direct.functions.allSatisfy { $0.couplingStatus != .needsModulePass })
    }

    @Test(
        "the module pass over swift-collections takes under 2 s in a release build",
        .enabled(if: FileManager.default.fileExists(atPath: collections))
    )
    func speed() throws {
        let targets = try FileManager.default.contentsOfDirectory(atPath: Self.collections).sorted()
        let inputs = targets.map { Modules.input($0, Resolutions.files(under: Self.collections + "/" + $0)) }
        let clock = ContinuousClock()
        let elapsed = clock.measure {
            for input in inputs {
                _ = SwiftCodeMetrics.analyzeModule(input)
            }
        }
        print("swift-collections: \(inputs.map(\.files.count).reduce(0, +)) files in \(elapsed)")

        // The spec's target is for optimised code (`swift test -c release`
        // measured 1.0 s); a debug build gets a loose bound against regressions.
        #if DEBUG
        #expect(elapsed < .seconds(10))
        #else
        #expect(elapsed < .seconds(2))
        #endif
    }
}
