//
//  CompositionLeaf.swift
//  SwiftCodeMetrics
//
//  One named type a typealias composition stands for (Spec §9.5).
//

/// A member of an expanded typealias composition.
struct CompositionLeaf {
    /// The member as written.
    let type: SpelledType
    /// The position it resolves from: its alias's own.
    let position: ResolutionContext
}
