//
//  RawFunctionReferences.swift
//  SwiftCodeMetrics
//
//  Everything the file pass records for one function record.
//

/// One function's raw references.
struct RawFunctionReferences: Codable, Hashable {
    /// Where the function sits.
    var context: FunctionContext
    /// Call sites, pattern-position calls excluded.
    var calls: [RawCall]
    /// Bare value names other than callees.
    var names: [RawName]
    /// `Base.member` accesses that are not callees.
    var memberReads: [RawMemberRead]
    /// Type names in the signature and body.
    var typeNames: [RawTypeName]
    /// Freestanding macro expansions in the body.
    var macroExpansionCount: Int
    /// Whether this record carries parameter counts.
    var carriesParameters: Bool
    /// The parameters, for the records that carry parameter counts; empty
    /// otherwise.
    var parameters: [RawParameter]
    /// Uses of `self` for the cohesion graph.
    var cohesion = RawCohesionFacts()
}
