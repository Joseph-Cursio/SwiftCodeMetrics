//
//  SwiftLintParityTests.swift
//  SwiftCodeMetricsTests
//
//  Spec §16: SL equals SwiftLint 0.65.1's `cyclomatic_complexity` for every
//  `func` and `init`, on the fixtures and on three real code bases, with
//  and without `ignores_case_statements`. Skipped when SwiftLint 0.65.1 or
//  a corpus is missing.
//

import Foundation
import Testing

@Suite("SwiftLint parity (Spec §4.3)", .enabled(if: SwiftLintRunner.isAvailable, "needs swiftlint 0.65.1"))
struct SwiftLintParityTests {
    /// The corpora the spec names, where they exist on this machine.
    private static let corpora: [String] = [
        "~/xcode_projects/SwiftStats/Sources",
        "~/xcode_projects/SwiftProjectLint",
        "~/GitHub_projects/swift-collections/Sources"
    ]
    .map { FileManager.default.homeDirectoryForCurrentUser.path + $0.dropFirst() }

    @Test("the fixtures agree with SwiftLint", arguments: [false, true])
    func fixtures(ignoresCaseStatements: Bool) throws {
        let files = Fixtures.names.map { Fixtures.directory.appendingPathComponent($0).path }
        let result = try ParityCheck.mismatches(in: files, ignoresCaseStatements: ignoresCaseStatements)

        #expect(result.checked >= 30)
        #expect(result.mismatches.isEmpty, "\(result.mismatches.joined(separator: "\n"))")
    }

    @Test("real code agrees with SwiftLint", arguments: corpora, [false, true])
    func corpus(root: String, ignoresCaseStatements: Bool) throws {
        try #require(FileManager.default.fileExists(atPath: root), "corpus missing: \(root)")
        let files = ParityCheck.swiftFiles(under: root)
        let result = try ParityCheck.mismatches(in: files, ignoresCaseStatements: ignoresCaseStatements)

        #expect(result.checked > 100)
        #expect(result.mismatches.isEmpty, "\(result.mismatches.prefix(40).joined(separator: "\n"))")
    }
}
