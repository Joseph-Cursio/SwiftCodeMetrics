//
//  RecordFacts.swift
//  SwiftCodeMetrics
//
//  What the type pass needs to know about one resolved record.
//

/// A record's owning type and its uses of that type's members.
struct RecordFacts {
    /// The type the record belongs to.
    let owner: TypeKey
    /// The declaring file.
    let file: String
    /// Whether the record is `static` or `class`.
    let isTypeLevel: Bool
    /// Its uses of the owner's members.
    let references: SelfReferences
}
