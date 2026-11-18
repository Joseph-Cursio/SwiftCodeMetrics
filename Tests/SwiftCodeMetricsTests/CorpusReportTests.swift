//
//  CorpusReportTests.swift
//  SwiftCodeMetricsTests
//
//  Spec §16 v0.3 corpus report: the share of types with LCOM4 > 1 over
//  types with |A| ≥ 2, and the counts of unresolved and ambiguous type
//  names, for the six corpora. The figures feed Q31 and Q28.
//
//  It takes about half a minute in a debug build, so it runs only when
//  SCM_CORPUS_REPORT is set: `SCM_CORPUS_REPORT=1 swift test --filter CorpusReport`.
//

import Foundation
import SwiftCodeMetrics
import Testing

@Suite("Corpus report (Spec §16 v0.3)")
struct CorpusReportTests {
    private static let home = FileManager.default.homeDirectoryForCurrentUser.path
    /// Each corpus and the directories of its modules.
    private static let corpora: [(name: String, modules: [String])] = [
        ("swift-collections", targets(under: "/GitHub_projects/swift-collections/Sources")),
        ("swift-nio", targets(under: "/GitHub_projects/swift-nio/Sources")),
        ("GRDB", [home + "/GitHub_projects/GRDB.swift/GRDB"]),
        ("TCA", targets(under: "/GitHub_projects/swift-composable-architecture/Sources")),
        ("SwiftProjectLint", targets(under: "/xcode_projects/SwiftProjectLint/Sources")),
        ("SwiftStats", targets(under: "/xcode_projects/SwiftStats/Sources"))
    ].filter { $0.modules.isEmpty == false }
    /// Whether the report was asked for.
    private static let isRequested = ProcessInfo.processInfo.environment["SCM_CORPUS_REPORT"] != nil

    /// The module directories under `relative`.
    private static func targets(under relative: String) -> [String] {
        let root = home + relative
        let names = (try? FileManager.default.contentsOfDirectory(atPath: root)) ?? []
        return names.sorted().map { root + "/" + $0 }.filter { path in
            var isDirectory: ObjCBool = false
            return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
        }
    }

    @Test(
        "LCOM4 > 1 over |A| ≥ 2, and unresolved and ambiguous type names, per corpus",
        .enabled(if: isRequested && corpora.isEmpty == false)
    )
    func report() {
        var lines = ["corpus | types | |A| ≥ 2 | LCOM4 > 1 | share | unresolved | ambiguous"]
        for corpus in Self.corpora {
            let types = corpus.modules.flatMap { directory in
                let name = URL(fileURLWithPath: directory).lastPathComponent
                return Modules.analysis(name, Resolutions.files(under: directory)).types
            }
            let eligible = types.filter { $0.cohesion.attributeCount >= 2 }
            let split = eligible.filter { ($0.cohesion.lcom4 ?? 0) > 1 }
            let share = eligible.isEmpty ? 0 : Double(split.count) / Double(eligible.count)
            let unresolved = types.map(\.coupling.unresolvedTypeRefCount).reduce(0, +)
            let ambiguous = types.map(\.coupling.ambiguousTypeRefCount).reduce(0, +)
            lines.append([
                corpus.name, "\(types.count)", "\(eligible.count)", "\(split.count)",
                String(format: "%.1f%%", share * 100), "\(unresolved)", "\(ambiguous)"
            ].joined(separator: " | "))
            #expect(eligible.isEmpty == false, "\(corpus.name)")
            #expect((0...1).contains(share), "\(corpus.name)")
        }
        print(lines.joined(separator: "\n"))
    }
}
