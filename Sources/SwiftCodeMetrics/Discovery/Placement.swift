//
//  Placement.swift
//  SwiftCodeMetrics
//
//  Where a variable declaration sits, which decides whether its initial
//  value is part of a body or a record of its own (Spec §2.1).
//

/// The position of a variable declaration.
enum Placement {
    /// At file scope.
    case global
    /// In a function body or closure.
    case local
    /// In a type's or extension's member list.
    case member
}
