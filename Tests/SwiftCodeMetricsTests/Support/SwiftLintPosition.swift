//
//  SwiftLintPosition.swift
//  SwiftCodeMetricsTests
//
//  Where SwiftLint reports a function: its `static`/`class` modifier, its
//  `func` keyword or its `init` keyword.
//

/// A file position.
struct SwiftLintPosition: Hashable, CustomStringConvertible {
    /// The file path.
    let file: String
    /// The 1-based line.
    let line: Int
    /// The 1-based column.
    let column: Int

    var description: String {
        "\(file):\(line):\(column)"
    }
}
