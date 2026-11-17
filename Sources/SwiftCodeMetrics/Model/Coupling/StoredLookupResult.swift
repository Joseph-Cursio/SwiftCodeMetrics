//
//  StoredLookupResult.swift
//  SwiftCodeMetrics
//
//  A lexical-lookup result without syntax nodes, so a file pass can be
//  encoded and the module pass gives the same answers (Spec §13.5).
//

/// One result of `lookup(_:with:)`, in walk order.
public enum StoredLookupResult: Sendable, Codable, Hashable {
    /// `.lookForGenericParameters(of:)`: the extension's extended type, as written.
    case genericParameters(typePath: [String])
    /// `.lookForImplicitClosureParameters`.
    case implicitClosureParameters
    /// `.fromScope` with names: a local, parameter, closure parameter or capture.
    case local
    /// `.lookForMembers(in:)`: the type's lexical path; an extension's part as written.
    case members(typePath: [String])
}
