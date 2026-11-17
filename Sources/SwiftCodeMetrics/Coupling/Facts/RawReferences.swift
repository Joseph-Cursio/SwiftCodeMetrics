//
//  RawReferences.swift
//  SwiftCodeMetrics
//
//  One file's raw references, per function record. Opaque to callers.
//

/// Raw references, aligned with `FileAnalysis.functions` by record id.
public struct RawReferences: Sendable, Codable, Hashable {
    /// Per record; nil for records with no function-level coupling.
    var functions: [RawFunctionReferences?] = []
}
