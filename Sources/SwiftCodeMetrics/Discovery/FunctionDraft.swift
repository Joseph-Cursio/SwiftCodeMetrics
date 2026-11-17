//
//  FunctionDraft.swift
//  SwiftCodeMetrics
//
//  A record before it has its final position and id.
//

/// A collected record, in visit order.
struct FunctionDraft {
    /// The enclosing record's draft index.
    let parentDraft: Int?
    /// The syntactic key.
    let key: MemberKey
    /// The key as one string, used as the prefix of nested keys.
    let fullKey: String
    /// The kind of body.
    let kind: FunctionKind
    /// The readable name.
    let name: String
    /// The declaration's span.
    let range: ByteRange
    /// The span in lines, when locations are known.
    let lines: LineRange?
    /// The scores.
    let complexity: ComplexityScores
    /// The raw references; nil for records with no function-level coupling.
    let raw: RawFunctionReferences?
}
