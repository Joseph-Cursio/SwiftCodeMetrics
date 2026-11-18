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
        input(module, files, isTest: false)
    }

    /// The input for `files`, a test module when `isTest`.
    static func input(_ module: String, _ files: [(path: String, source: String)], isTest: Bool) -> ModuleInput {
        let inputs = files.map { SourceFileInput(path: $0.path, tree: Parser.parse(source: $0.source)) }
        return ModuleInput(name: module, files: inputs, isTest: isTest)
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

    /// The non-local type whose path is `path`, dot-separated.
    static func type(_ path: String, in analysis: ModuleAnalysis) -> TypeResult? {
        analysis.types.first { $0.key.path.joined(separator: ".") == path && $0.key.localTo == nil }
    }

    /// The members of each counted cohesion component, as declaration text after the type path.
    static func components(_ type: TypeResult?) -> [[String]] {
        (type?.cohesion.components ?? []).map { component in component.members.map(memberName) }
    }

    /// A member key's declaration, without its type path: `func add(_: Item)`.
    static func memberName(_ key: MemberKey) -> String {
        key.text.components(separatedBy: "::").last ?? key.text
    }

    /// The targets of a type's edges, as dotted paths.
    static func targets(of type: TypeResult?, in analysis: ModuleAnalysis) -> [String] {
        analysis.typeEdges.filter { $0.source == type?.key }.map { $0.target.path.joined(separator: ".") }
    }
}
