//
//  Fixtures.swift
//  SwiftCodeMetricsTests
//
//  Loads the Swift sources under Fixtures/ and scores them.
//

import Foundation
import SwiftCodeMetrics
import SwiftOperators
import SwiftParser
import SwiftSyntax

/// Access to the fixture files.
enum Fixtures {
    /// Every fixture's file name, sorted.
    static var names: [String] {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        return files.filter { $0.hasSuffix(".swift") }.sorted()
    }

    /// The fixture directory inside the test bundle.
    static var directory: URL {
        Bundle.module.resourceURL?.appendingPathComponent("Fixtures") ?? URL(fileURLWithPath: "Fixtures")
    }

    /// The source of a fixture.
    static func source(_ name: String) -> String {
        (try? String(contentsOf: directory.appendingPathComponent(name), encoding: .utf8)) ?? ""
    }

    /// A fixture scored as a file with default options.
    static func analysis(_ name: String) -> FunctionAnalysis {
        score(source(name), path: name, options: MetricsOptions(), folded: false)
    }

    /// A fixture scored as a file with `options`.
    static func analysis(_ name: String, options: MetricsOptions) -> FunctionAnalysis {
        score(source(name), path: name, options: options, folded: false)
    }

    /// A fixture scored as a file, folded with SwiftOperators first when `folded`.
    static func analysis(_ name: String, folded: Bool) -> FunctionAnalysis {
        score(source(name), path: name, options: MetricsOptions(), folded: folded)
    }

    /// Source text scored as `Test.swift`.
    static func analysis(source: String) -> FunctionAnalysis {
        score(source, path: "Test.swift", options: MetricsOptions(), folded: false)
    }

    /// Source text scored as the file at `path`.
    static func analysis(source: String, path: String) -> FunctionAnalysis {
        score(source, path: path, options: MetricsOptions(), folded: false)
    }

    /// Source text scored with `options`.
    static func analysis(source: String, options: MetricsOptions) -> FunctionAnalysis {
        score(source, path: "Test.swift", options: options, folded: false)
    }

    /// Source text scored after folding with SwiftOperators when `folded`.
    static func analysis(source: String, folded: Bool) -> FunctionAnalysis {
        score(source, path: "Test.swift", options: MetricsOptions(), folded: folded)
    }

    /// The record called `name` in `analysis`.
    static func record(_ name: String, in analysis: FunctionAnalysis) -> FunctionRecord? {
        analysis.functions.first { $0.name == name }
    }

    /// Parses, optionally folds, and scores `source` in module `Lib`.
    private static func score(
        _ source: String,
        path: String,
        options: MetricsOptions,
        folded: Bool
    ) -> FunctionAnalysis {
        var tree = Parser.parse(source: source)
        if folded {
            let foldedTree = OperatorTable.standardOperators.foldAll(tree) { _ in
                // Unknown operators stay unfolded; the fixtures use none.
            }
            tree = foldedTree.as(SourceFileSyntax.self) ?? tree
        }
        let input = SourceFileInput(path: path, tree: tree)
        return SwiftCodeMetrics.functionMetrics(of: input, module: "Lib", options: options)
    }
}
