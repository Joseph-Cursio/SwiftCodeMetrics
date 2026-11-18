//
//  MemberPlace.swift
//  SwiftCodeMetrics
//
//  Where a member named after `self.` is declared (Spec §9.3).
//

/// The declaring type of a `self.` member.
enum MemberPlace {
    /// An in-module superclass.
    case inherited
    /// The type itself, merged with its extensions.
    case own
    /// Neither: a protocol default or an outside superclass.
    case undeclared
}
