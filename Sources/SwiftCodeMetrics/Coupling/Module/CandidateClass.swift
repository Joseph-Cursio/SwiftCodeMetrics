//
//  CandidateClass.swift
//  SwiftCodeMetrics
//
//  How an uppercase name in expression position is classified (Spec §7.3).
//

/// The classification of a type-name candidate.
enum CandidateClass {
    /// A free function of the module or the platform.
    case freeFunction
    /// A module global.
    case global(GlobalFact)
    /// Not a candidate: a local, a member or a module name.
    case notCandidate
    /// A type, resolved.
    case type(TypeResolution)
}
