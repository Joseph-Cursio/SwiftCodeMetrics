//
//  RecursionMatch.swift
//  SwiftCodeMetrics
//
//  What one call means for the recursion check (Spec §3.4).
//

import SwiftSyntax

/// The verdict on a call that names the function; calls that don't are nil.
enum RecursionMatch {
    /// A direct call of the function itself.
    case direct(TokenSyntax)
    /// A call on another receiver whose name and labels match.
    case possible(TokenSyntax)
}
