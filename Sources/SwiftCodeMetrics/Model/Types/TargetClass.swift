//
//  TargetClass.swift
//  SwiftCodeMetrics
//
//  The ce split of a target (Spec §9.4).
//

/// What a `ce` target is, checked in the order protocol, view, namespace, concrete.
public enum TargetClass: String, Sendable, Codable, Hashable {
    /// A protocol.
    case `protocol`
    /// Anything else.
    case concrete
    /// An enum with no cases whose members are all static.
    case namespace
    /// A SwiftUI view.
    case view
}
