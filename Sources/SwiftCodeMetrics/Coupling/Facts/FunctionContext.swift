//
//  FunctionContext.swift
//  SwiftCodeMetrics
//
//  Where a function sits, as name resolution needs it (Spec §7.2, §7.3).
//

/// The lexical surroundings of one function.
struct FunctionContext: Codable, Hashable {
    /// The enclosing type's lexical path; an extension contributes its
    /// extended type as written. Empty at file scope.
    var typePath: [String]
    /// How many leading `typePath` components came from an extension.
    var extensionPathLength: Int
    /// The function that owns the enclosing type, when that type is local.
    var localOwner: MemberKey?
    /// Enclosing records, nearest last: the owners of visible local types.
    var enclosingRecords: [MemberKey]
    /// Generic parameters and associated types visible here.
    var genericParameters: [String]
    /// Whether the function is `static` or `class`.
    var isTypeLevel: Bool
    /// The file, for `private` types.
    var file: String
}
