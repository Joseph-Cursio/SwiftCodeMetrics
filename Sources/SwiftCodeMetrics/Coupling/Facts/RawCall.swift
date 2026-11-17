//
//  RawCall.swift
//  SwiftCodeMetrics
//
//  One call site found by the file pass.
//

/// A call site before key building.
struct RawCall: Codable, Hashable {
    /// The callee's form.
    var shape: CalleeShape
    /// The base name: `append`, or `init` for `Self(...)`.
    var name: String
    /// Argument labels, `_` when absent, trailing closures included.
    var labels: [String]
    /// The callee's start.
    var offset: Int
}
