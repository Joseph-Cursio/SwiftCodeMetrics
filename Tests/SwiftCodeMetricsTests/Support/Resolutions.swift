//
//  Resolutions.swift
//  SwiftCodeMetricsTests
//
//  Exposes the internal value resolution of one function's bare names, for
//  the resolver tests (Spec Q25).
//

import Foundation
@testable import SwiftCodeMetrics
import SwiftParser

/// Resolves the bare names of one function.
enum Resolutions {
    /// Each bare name of the record called `function` (or whose key ends with
    /// `keySuffix`), with its resolution.
    static func names(
        _ module: String,
        _ files: [(path: String, source: String)],
        function: String
    ) -> [(name: String, resolution: String)] {
        let analyses = files.map { file in
            SwiftCodeMetrics.analyzeFile(
                SourceFileInput(path: file.path, tree: Parser.parse(source: file.source)),
                module: module
            )
        }
        let table = SymbolTable(module: module, files: analyses, platform: .bundled)
        for analysis in analyses {
            for (index, record) in analysis.functions.enumerated()
            where record.name == function || record.key.description.hasSuffix(function) {
                guard let raw = analysis.rawReferences.functions[index] else {
                    continue
                }
                let resolver = FunctionResolver(
                    table: table,
                    raw: raw,
                    imports: analysis.imports,
                    options: MetricsOptions()
                )
                return raw.names.map { ($0.name, describe(resolver.resolveValue($0.name, lookup: $0.lookup))) }
            }
        }
        return []
    }

    /// The Swift files of a directory, as path and source.
    static func files(under root: String) -> [(path: String, source: String)] {
        ParityCheck.swiftFiles(under: root).compactMap { path in
            (try? String(contentsOfFile: path, encoding: .utf8)).map { (path, $0) }
        }
    }

    /// A short description of a resolution.
    private static func describe(_ resolution: ValueResolution) -> String {
        switch resolution {
        case .enumCase(let owner):
            "case " + owner.path.joined(separator: ".")

        case .freeFunction:
            "free"

        case .global:
            "global"

        case .inheritedMember:
            "inherited"

        case .notCoupling:
            "local"

        case .ownMember:
            "own"

        case .staticMember(let owner, _):
            "static " + owner.path.joined(separator: ".")

        case .unresolved:
            "unresolved"
        }
    }
}
