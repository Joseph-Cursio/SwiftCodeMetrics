//
//  TypeKey.swift
//  SwiftCodeMetrics
//
//  A type's identity: module plus nominal path (Spec §2.2). Shared with
//  SwiftStats' index collector, which writes the same shape.
//

/// Identifies a type.
public struct TypeKey: Hashable, Sendable, Codable, CustomStringConvertible {
    /// The module.
    public var module: String
    /// The nominal path, generic arguments stripped: `["Heap", "_UnsafeHandle"]`.
    public var path: [String]
    /// The file, only for a `private` or `fileprivate` type.
    public var file: String?
    /// The function key, only for a type declared in a function body.
    public var localTo: MemberKey?

    /// `Module.Path`, with the file or owning function when set.
    public var description: String {
        var text = ([module] + path).joined(separator: ".")
        if let localTo {
            text += " in " + localTo.description
        }
        if let file {
            text += " @ " + file
        }
        return text
    }

    /// Creates a key.
    public init(module: String, path: [String], file: String? = nil, localTo: MemberKey? = nil) {
        self.module = module
        self.path = path
        self.file = file
        self.localTo = localTo
    }
}
