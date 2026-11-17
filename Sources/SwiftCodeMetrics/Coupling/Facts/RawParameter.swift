//
//  RawParameter.swift
//  SwiftCodeMetrics
//
//  One parameter, as the parameter counts need it (Spec §8.3).
//

/// A parameter before typealias expansion.
struct RawParameter: Codable, Hashable {
    /// It has a default value.
    var hasDefault: Bool
    /// It is variadic.
    var isVariadic: Bool
    /// It is `inout`.
    var isInout: Bool
    /// Its type, as far as closures go.
    var shape: ClosureShape
}
