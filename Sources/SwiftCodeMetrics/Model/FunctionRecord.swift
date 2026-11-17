//
//  FunctionRecord.swift
//  SwiftCodeMetrics
//
//  One scored body (Spec §2.1, §13.2). Coupling fields arrive in v0.2.
//

/// One function and its complexity scores.
public struct FunctionRecord: Sendable, Codable, Hashable, Identifiable {
    /// The index in the returned array, in record order (Spec §13.1).
    public let id: Int
    /// The enclosing record, for nested and local functions.
    public let parentID: Int?
    /// The PRD §6.1 syntactic key.
    public let key: MemberKey
    /// The enclosing record's key.
    public let parentKey: MemberKey?
    /// The kind of body.
    public let kind: FunctionKind
    /// A readable name, such as `loadConfig(from:attempt:)` or `body.get`.
    public let name: String
    /// The declaration's span, without leading and trailing trivia.
    public let range: ByteRange
    /// The same span in lines and columns, when locations are known.
    public let lines: LineRange?
    /// The scores; final at every level.
    public let complexity: ComplexityScores
    /// Whether coupling values are final. Always `.needsModulePass` or
    /// `.notApplicableKind` in v0.1.
    public let couplingStatus: CouplingStatus
}
