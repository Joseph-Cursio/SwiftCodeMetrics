//
//  Provenance.swift
//  SwiftCodeMetrics
//
//  Where an edge came from (Spec §13.4).
//

/// The source of an edge.
public enum Provenance: String, Sendable, Codable, Hashable {
    /// An index store.
    case index
    /// This library's syntax pass.
    case syntax
}
