//
//  LineRange.swift
//  SwiftCodeMetrics
//
//  A span of a file in lines and columns, as PRD §6.1 asks each record to store.
//

/// Start and end line and column, 1-based. The end is the last character.
public struct LineRange: Sendable, Codable, Hashable {
    /// The first line.
    public let startLine: Int
    /// The column of the first character.
    public let startColumn: Int
    /// The last line.
    public let endLine: Int
    /// The column of the last character.
    public let endColumn: Int
}
