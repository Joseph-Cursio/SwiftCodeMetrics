//
//  SwiftLintViolation.swift
//  SwiftCodeMetricsTests
//
//  One entry of SwiftLint's JSON report.
//

/// A reported violation.
struct SwiftLintViolation: Decodable {
    /// The file path.
    let file: String
    /// The 1-based line.
    let line: Int
    /// The 1-based column, when reported.
    let character: Int?
    /// "… currently complexity is N".
    let reason: String

    /// The complexity in the reason text.
    var complexity: Int? {
        reason.split(separator: " ").last.flatMap { Int($0) }
    }
}
