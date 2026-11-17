//
//  TypeBucket.swift
//  SwiftCodeMetrics
//
//  Where a resolved type name comes from (Spec §7.3).
//

/// The outcome bucket of a type name.
public enum TypeBucket: String, Sendable, Codable {
    /// Not declared in the module and not in the platform table.
    case external
    /// A type of this module.
    case module
    /// In the platform table.
    case platform
}
