//
//  ParameterCounts.swift
//  SwiftCodeMetrics
//
//  Data coupling through parameters (Spec §8.3).
//

/// Counts over a `func`, `init` or `subscript` parameter list.
public struct ParameterCounts: Sendable, Codable, Hashable {
    /// Every parameter.
    public var parameterCount: Int
    /// Parameters with a default value.
    public var defaultedParameterCount: Int
    /// Variadic parameters.
    public var variadicParameterCount: Int
    /// `inout` parameters.
    public var inoutParameterCount: Int
    /// Parameters of function type, after module typealiases are expanded.
    public var closureParameterCount: Int
    /// Closure parameters marked `@escaping` or optional.
    public var escapingClosureParameterCount: Int
}
