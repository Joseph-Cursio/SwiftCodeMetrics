//
//  RawCohesionFacts.swift
//  SwiftCodeMetrics
//
//  What one body does with self, for the cohesion graph (Spec §9.3).
//

/// A body's uses of its own type's members that the coupling facts do not hold.
struct RawCohesionFacts: Codable, Hashable {
    /// Members named after `self.` or `self?.` that are not called.
    var selfMembers: [String] = []
    /// Members named after `super.` that are not called.
    var superMembers: [String] = []
    /// Shorthand bindings `if let a` and `guard let a`, looked up at the condition.
    var shorthandBindings: [RawName] = []
    /// Key paths: their root as written (empty when rootless) and first property component.
    var keyPaths: [RawKeyPath] = []
    /// Uses of `self` as a whole value (Spec §9.3 rule 6).
    var wholeSelfUses = 0
    /// `self[...]` subscript calls.
    var selfSubscriptUses = 0
}
