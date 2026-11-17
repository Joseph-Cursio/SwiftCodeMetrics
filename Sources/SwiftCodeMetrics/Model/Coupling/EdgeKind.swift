//
//  EdgeKind.swift
//  SwiftCodeMetrics
//
//  Why one type depends on another (Spec §9.4). Functions use `signature`
//  and `body`; the declaration-level kinds arrive with v0.3.
//

/// The kind of a type dependency.
public enum EdgeKind: String, Sendable, Codable {
    /// A member typealias.
    case `typealias`
    /// The function's own body.
    case body
    /// An enum case's associated value.
    case casePayload = "case_payload"
    /// A conformance.
    case conformance
    /// A generic or `where` constraint on a type or extension.
    case constraint
    /// A superclass.
    case inheritance
    /// A protocol refining another.
    case refinement
    /// A function's parameters, result, generic clause or property type.
    case signature
    /// A stored property's type or initial value.
    case storedProperty = "stored_property"
    /// A property-wrapper attribute.
    case wrapper
}
