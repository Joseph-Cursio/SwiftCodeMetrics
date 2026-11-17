//
//  ReceiverKind.swift
//  SwiftCodeMetrics
//
//  Who a call goes to, as syntax can tell (Spec §7.5).
//

/// The receiver part of a call key.
public enum ReceiverKind: String, Sendable, Codable, CodingKeyRepresentable, CaseIterable {
    /// `self`, or a bare own or inherited member.
    case `self`
    /// `super`.
    case `super`
    /// The base is a call result.
    case chain
    /// A module free function or a platform free function.
    case free
    /// An unqualified callee no table resolves.
    case implicit
    /// `.member(...)` with no base.
    case implicitMember = "."
    /// A type name, or a bare static.
    case type = "T"
    /// Any other receiver expression.
    case unknown = "?"
}
