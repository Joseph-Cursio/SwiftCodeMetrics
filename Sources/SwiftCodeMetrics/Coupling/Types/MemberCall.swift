//
//  MemberCall.swift
//  SwiftCodeMetrics
//
//  A call of a member of the function's own type (Spec §9.3).
//

/// An own-member call: base name and labels.
struct MemberCall: Hashable {
    /// The base name.
    var name: String
    /// The argument labels.
    var labels: [String]
}
