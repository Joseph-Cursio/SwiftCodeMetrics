//
//  CohesionOptions.swift
//  SwiftCodeMetrics
//
//  Options for the cohesion metric (Spec §9.3, §13.1).
//

/// Cohesion options; each changes values, so each is part of the definition (Spec Q4).
public struct CohesionOptions: Sendable, Hashable, Codable {
    /// Leave `description`, `debugDescription` and `customMirror` out of M (Spec Q21).
    public var excludeDescriptionWitnesses = true
    /// A whole `self` in a struct touches every attribute (Spec §9.3 rule 6, Q20).
    public var wholeSelfInStructs = true
    /// Drop components that touch no attribute (Spec Q22).
    public var dropAttributeFreeComponents = true
    /// Add the stored properties of in-module superclasses to A (Spec Q32).
    public var inheritsModuleSuperclassAttributes = true

    /// The defaults.
    public init() {
        // Every property has a default.
    }
}
