//
//  Modules.swift
//  SwiftCodeMetricsTests
//
//  Builds module analyses from in-memory sources.
//

import SwiftCodeMetrics
import SwiftParser

/// Module-level helpers.
enum Modules {
    /// The module pass over `files`, each a path and its source.
    static func analysis(_ module: String, _ files: [(path: String, source: String)]) -> ModuleAnalysis {
        SwiftCodeMetrics.analyzeModule(input(module, files))
    }

    /// The input for `files`.
    static func input(_ module: String, _ files: [(path: String, source: String)]) -> ModuleInput {
        let inputs = files.map { SourceFileInput(path: $0.path, tree: Parser.parse(source: $0.source)) }
        return ModuleInput(name: module, files: inputs, isTest: false)
    }

    /// The record called `name`.
    static func record(_ name: String, in analysis: ModuleAnalysis) -> FunctionRecord? {
        analysis.functions.first { $0.name == name }
    }

    /// A record's headline call keys, sorted.
    static func headline(_ record: FunctionRecord?) -> [String] {
        (record?.fanOut?.calls ?? [])
            .filter { $0.receiver != .implicitMember && $0.receiver != .chain }
            .map(\.key)
            .sorted()
    }

    /// A record's call keys with `receiver`, sorted.
    static func keys(_ record: FunctionRecord?, _ receiver: ReceiverKind) -> [String] {
        (record?.fanOut?.calls ?? []).filter { $0.receiver == receiver }.map(\.key).sorted()
    }
}
