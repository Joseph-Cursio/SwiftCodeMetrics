//
//  Resolution.swift
//  SwiftCodeMetrics
//
//  How sure a reference's target is (Spec §13.5).
//

/// The certainty of a resolved reference.
public enum Resolution: String, Sendable, Codable {
    /// More than one module type matches; no target is guessed.
    case ambiguous
    /// The target is likely but not certain, such as an external name.
    case approximate
    /// The target is known.
    case exact
    /// The name matches only types it cannot reach (Spec §7.3 step 5).
    case unresolved
}
