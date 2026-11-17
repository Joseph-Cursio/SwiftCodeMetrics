//
//  CallKeyItem.swift
//  SwiftCodeMetrics
//
//  One distinct callee of a function: the breakdown behind fan-out.
//

/// A distinct call key and where it first appears.
public struct CallKeyItem: Sendable, Codable, Hashable {
    /// `self.touch()`, `?.append(_:)`, `Date.init()`, `free.max(_:_:)` (Spec §7.5).
    public var key: String
    /// The receiver kind.
    public var receiver: ReceiverKind
    /// Call sites with this key.
    public var siteCount: Int
    /// The callee of the first site.
    public var firstUTF8Offset: Int
}
