//
//  MemberKey.swift
//  SwiftCodeMetrics
//
//  The PRD §6.1 syntactic key of a function, rendered by the library so that
//  SwiftStats and SwiftProjectLint agree on identity (Spec §2.1, Q1).
//

/// A function's syntactic identity.
public struct MemberKey: Hashable, Sendable, Codable, CustomStringConvertible {
    /// The module name.
    public var module: String
    /// Every other key part in canonical form, `#if` condition included.
    public var text: String
    /// The file, only for `private` and `fileprivate` declarations.
    public var file: String?

    /// The key as SwiftStats writes it: `module::text`, then ` @ file` when set.
    public var description: String {
        module + "::" + text + (file.map { " @ " + $0 } ?? "")
    }

    /// Creates a key from its parts.
    public init(module: String, text: String, file: String? = nil) {
        self.module = module
        self.text = text
        self.file = file
    }
}
