//
//  ResultBuilderHint.swift
//  SwiftCodeMetrics
//
//  Marks bodies that are probably result builders, so a linter can apply a
//  higher threshold (Spec §5). The scores themselves never change. A body
//  that doesn't look like one has no hint (nil).
//

/// Why a function looks like a result-builder body.
public enum ResultBuilderHint: Sendable, Codable, Hashable {
    /// An attribute whose last name component ends in `Builder`, such as `ViewBuilder`.
    case attribute(String)
    /// A `some P` result whose protocol is in `opaqueResultBuilderProtocols`, such as `View`.
    case opaqueResult(String)
}
