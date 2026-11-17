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
