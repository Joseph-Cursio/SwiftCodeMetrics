//
//  LexicalPosition.swift
//  SwiftCodeMetrics
//
//  Where the collector currently is, in type and record terms.
//

/// The collector's lexical position.
struct LexicalPosition {
    /// The type path since the last record.
    var typePath: [String] = []
    /// How many leading components an extension contributed.
    var extensionPathLength = 0
    /// Whether any type on the path is file-scoped.
    var isFileScoped = false
    /// The record that owns the path, when the types are local.
    var localOwner: MemberKey?
    /// Every enclosing record, nearest last.
    var enclosingRecords: [MemberKey] = []
    /// Generic parameters visible here.
    var genericParameters: [String] = []
    /// Set when a record is the innermost scope: a type declared next starts
    /// a new path, owned by that record or key context.
    var pendingOwner: MemberKey?
    /// For a local type: the type path around the record that owns it.
    var enclosingTypePath: [String] = []
    /// For a local type: that path's own local owner, if it is local too.
    var enclosingLocalOwner: MemberKey?

    /// The position a type declared here starts from.
    func enteringType() -> Self {
        guard let owner = pendingOwner else {
            return self
        }
        var position = self
        position.enclosingTypePath = typePath
        position.enclosingLocalOwner = localOwner
        position.typePath = []
        position.extensionPathLength = 0
        position.isFileScoped = false
        position.localOwner = owner
        position.pendingOwner = nil
        return position
    }
}
