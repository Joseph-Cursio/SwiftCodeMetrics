//
//  ParityCheck.swift
//  SwiftCodeMetricsTests
//
//  Compares the library's SL with SwiftLint's own number for every `func`
//  and `init` with a body in a set of files.
//

import Foundation
import SwiftCodeMetrics
import SwiftParser
import SwiftSyntax

/// Runs the SL parity comparison.
enum ParityCheck {
    /// Every mismatch, as "file:line:column library≠swiftlint", for `files`.
    static func mismatches(
        in files: [String],
        ignoresCaseStatements: Bool
    ) throws -> (checked: Int, mismatches: [String]) {
        let reported = try SwiftLintRunner.complexities(of: files, ignoresCaseStatements: ignoresCaseStatements)
        var options = MetricsOptions()
        options.complexity.swiftLintIgnoresCaseStatements = ignoresCaseStatements
        var checked = 0
        var mismatches: [String] = []
        for file in files {
            guard let source = try? String(contentsOfFile: file, encoding: .utf8) else {
                continue
            }
            let tree = Parser.parse(source: source)
            let analysis = SwiftCodeMetrics.functionMetrics(
                of: SourceFileInput(path: file, tree: tree),
                options: options
            )
            let scored = analysis.functions.filter(\.complexity.swiftLintScoresKind)
            let byStart = Dictionary(scored.map { ($0.range.start, $0) }) { first, _ in first }
            let converter = SourceLocationConverter(fileName: file, tree: tree)
            for target in ReportedFunctions.collect(tree) {
                guard let record = byStart[target.start] else {
                    mismatches.append("\(file): no record at offset \(target.start)")
                    continue
                }
                let location = converter.location(for: target.token)
                let position = SwiftLintPosition(file: file, line: location.line, column: location.column)
                let expected = reported[position] ?? 0
                checked += 1
                if record.complexity.swiftLintCompatible != expected {
                    let actual = record.complexity.swiftLintCompatible
                    mismatches.append("\(position) \(record.name): library \(actual), SwiftLint \(expected)")
                }
            }
        }
        return (checked, mismatches)
    }

    /// The Swift files under `root`, skipping hidden and build directories.
    static func swiftFiles(under root: String) -> [String] {
        guard let enumerator = FileManager.default.enumerator(atPath: root) else {
            return []
        }
        var files: [String] = []
        while let relative = enumerator.nextObject() as? String {
            let components = relative.split(separator: "/")
            if components.contains(where: { $0.hasPrefix(".") }) {
                enumerator.skipDescendants()
                continue
            }
            if relative.hasSuffix(".swift") {
                files.append(root + "/" + relative)
            }
        }
        return files.sorted()
    }
}
