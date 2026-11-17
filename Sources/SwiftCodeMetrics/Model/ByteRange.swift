//
//  ByteRange.swift
//  SwiftCodeMetrics
//
//  A span of a file in UTF-8 offsets, as `AbsolutePosition.utf8Offset` gives.
//

/// UTF-8 byte offsets from the start of the file.
public struct ByteRange: Sendable, Codable, Hashable {
    /// The first byte, inclusive.
    public let start: Int
    /// The byte after the last, exclusive.
    public let end: Int
}
