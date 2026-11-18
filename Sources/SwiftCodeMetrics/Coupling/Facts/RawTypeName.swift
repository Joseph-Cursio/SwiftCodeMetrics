//
//  RawTypeName.swift
//  SwiftCodeMetrics
//
//  A type name in a signature or body: written as a type, or an uppercase
//  name in expression position (a type-name candidate, Spec §7.3).
//

/// A type name before resolution.
struct RawTypeName: Codable, Hashable {
    /// The name as written.
    var type: SpelledType
    /// `signature` or `body`.
    var edgeKind: EdgeKind
    /// Where it starts.
    var offset: Int
    /// Whether this is an expression type-name candidate rather than a
    /// written type.
    var isCandidate: Bool
    /// For an expression candidate, its lookup results (possibly none);
    /// always empty for a written type.
    var lookup: [StoredLookupResult]
    /// For `Root.Type` in an expression: the type counts only if the module
    /// pass finds that `Root`, held as the module selector, names a module.
    var qualifierMustBeModule = false
    /// For a stored property's type name: whether the property is `weak` or `unowned`.
    var isWeakOrUnowned = false
    /// For an expression candidate `A.B.C`: the uppercase member names after
    /// it, so the reference targets the nested type `A.B` (Spec §7.3 step 4).
    var trailingMembers: [String] = []
    /// For a name in an inheritance clause: the index of its entry, whose
    /// first name decides the edge kind of all of them.
    var inheritanceEntry: Int?
    /// For a constraint in a type's generic parameter clause: it resolves
    /// outside the body, like the inheritance clause.
    var isInGenericClause = false

    /// The reference before the module pass resolves it.
    var unresolvedReference: TypeReference {
        TypeReference(
            spelling: type.spelling,
            edgeKind: edgeKind,
            utf8Offset: offset,
            bucket: nil,
            target: nil,
            resolution: .unresolved
        )
    }
}
