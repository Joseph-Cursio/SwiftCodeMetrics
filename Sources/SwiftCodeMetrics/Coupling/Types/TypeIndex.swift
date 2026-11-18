//
//  TypeIndex.swift
//  SwiftCodeMetrics
//
//  Module-wide facts about types, computed once per module pass: nesting
//  families, the types nested in each type, and conformance closures.
//

/// Precomputed type relations.
struct TypeIndex {
    /// Each type's family root (Spec §2.2).
    private(set) var familyRoots: [TypeKey: TypeKey] = [:]
    /// Each type and every type nested in it, at any depth.
    private(set) var subtrees: [TypeKey: [TypeKey]] = [:]

    /// The index of `keys`.
    init(keys: [TypeKey], table: SymbolTable) {
        for key in keys {
            let chain = table.chain(from: key)
            familyRoots[key] = chain.last ?? key
            for ancestor in chain {
                subtrees[ancestor, default: []].append(key)
            }
        }
    }

    /// The family root of `key`.
    func familyRoot(of key: TypeKey) -> TypeKey {
        familyRoots[key] ?? key
    }
}
