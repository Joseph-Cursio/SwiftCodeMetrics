//
//  CallArgument.swift
//  SwiftCodeMetrics
//
//  One argument of a call, as label matching sees it (Spec §3.4 rule 4).
//

import SwiftSyntax

/// A labelled (or `_`) argument, or the first trailing closure.
enum CallArgument: Equatable {
    /// A parenthesised argument or a further trailing closure.
    case labeled(String)
    /// The first trailing closure, which binds by the SE-0286 forward scan.
    case trailingClosure

    /// The arguments of `call`, in order.
    static func arguments(of call: FunctionCallExprSyntax) -> [Self] {
        var arguments = call.arguments.map { Self.labeled($0.label?.text ?? "_") }
        if call.trailingClosure != nil {
            arguments.append(.trailingClosure)
        }
        for closure in call.additionalTrailingClosures {
            arguments.append(.labeled(closure.label.text))
        }
        return arguments
    }
}
