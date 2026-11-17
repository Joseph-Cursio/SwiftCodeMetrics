//
//  CouplingStatus.swift
//  SwiftCodeMetrics
//
//  Whether a record's coupling values are final (Spec §13.2).
//

/// The state of a record's coupling values.
public enum CouplingStatus: String, Sendable, Codable {
    /// Computed by the module pass.
    case computed
    /// Function level, or a file pass not yet merged. Always the case in v0.1.
    case needsModulePass = "needs_module_pass"
    /// `.propertyInitializer` records carry complexity only (Spec §2.1).
    case notApplicableKind = "not_applicable_kind"
}
