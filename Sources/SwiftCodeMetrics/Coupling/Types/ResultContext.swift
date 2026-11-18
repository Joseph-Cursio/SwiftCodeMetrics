//
//  ResultContext.swift
//  SwiftCodeMetrics
//
//  The module-wide values one TypeResult needs.
//

/// What assembling one type's result needs from the rest of the module.
struct ResultContext {
    /// Every type's draft.
    let drafts: [TypeKey: TypeDraft]
    /// Families and nesting.
    let index: TypeIndex
    /// The type's own outgoing edges.
    let edges: [TypeCoupling]
    /// The number of types with an edge to it.
    let incoming: Int
    /// For a protocol: the number of conforming module types.
    let conformers: Int
}
