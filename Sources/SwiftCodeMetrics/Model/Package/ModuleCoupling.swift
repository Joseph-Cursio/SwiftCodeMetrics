//
//  ModuleCoupling.swift
//  SwiftCodeMetrics
//
//  A module's import coupling (Spec §10.2).
//

/// Module-level Ce, Ca and instability.
public struct ModuleCoupling: Sendable, Codable, Hashable {
    /// The module.
    public var module: String
    /// Whether it is a test module.
    public var isTest: Bool
    /// Distinct imported modules, the module itself and the implicit ones excluded.
    public var ceAll: Int
    /// The imported modules that are scanned.
    public var cePackage: Int
    /// `cePackage` plus the scanned modules they re-export, transitively.
    public var ceWithReexports: Int
    /// `ca`: scanned non-test modules that import this one directly.
    public var caDirect: Int
    /// Scanned non-test modules that import it directly or through re-exports.
    public var caWithReexports: Int
    /// Scanned test modules that import it directly.
    public var caTests: Int
    /// `cePackage / (caDirect + cePackage)`; nil when both are 0.
    public var instability: Double?
}
