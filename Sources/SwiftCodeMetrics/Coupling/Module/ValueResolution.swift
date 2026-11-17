//
//  ValueResolution.swift
//  SwiftCodeMetrics
//
//  What an unqualified value name resolved to (Spec §7.2).
//

/// The outcome of resolving a bare name.
enum ValueResolution {
    /// An enum case of the current or an enclosing type: not a static for
    /// `staticRefs`, but a call of one is keyed on that type.
    case enumCase(TypeKey)
    /// A free function of the module.
    case freeFunction
    /// A module global.
    case global(GlobalFact)
    /// A member of the in-module superclass chain.
    case inheritedMember
    /// A local, parameter, closure parameter, generic parameter or enum case: not coupling.
    case notCoupling
    /// An instance member of the current type.
    case ownMember
    /// A static of the current type, an enclosing type or a superclass.
    case staticMember(TypeKey, MemberFact)
    /// Nothing the module declares: inherited from outside, a protocol default, macro-added or imported.
    case unresolved
}
