//
//  LogicalToken.swift
//  SwiftCodeMetrics
//
//  One entry of a logical-operator token list (Spec §3.5.2).
//

import SwiftSyntax

/// An `&&` or `||`, or a break in the sequence.
enum LogicalToken: Equatable {
    /// An ends-the-run marker: a ternary, assignment or `->`.
    case boundary
    /// A logical operator, with its token for anchoring.
    case logical(text: String, token: TokenSyntax)
}
