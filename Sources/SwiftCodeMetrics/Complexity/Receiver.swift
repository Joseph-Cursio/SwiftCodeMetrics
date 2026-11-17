//
//  Receiver.swift
//  SwiftCodeMetrics
//
//  Whose member a call names, for the recursion check.
//

/// The receiver of a member call.
enum Receiver {
    /// Any other receiver: another instance, a type, an implicit member.
    case other
    /// `self`, or `Self` inside a `static` or `class` function.
    case ownSelf
}
