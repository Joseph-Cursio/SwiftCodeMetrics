//
//  CommonCoupling.swift
//  SwiftCodeMetrics
//
//  Shared state a function reaches: globals, statics and singletons
//  (Spec §8.2). Each list holds distinct names.
//

/// The globals, statics and singletons a function references.
public struct CommonCoupling: Sendable, Codable, Hashable {
    /// Module globals.
    public var globals: [String]
    /// Globals declared as stored `var`.
    public var mutableGlobals: [String]
    /// Static properties of module types: `APIClient.verbose`.
    public var statics: [String]
    /// Statics declared as stored `static var`.
    public var mutableStatics: [String]
    /// Singleton references: `APIClient.shared`.
    public var singletons: [String]

    /// `globals.count`.
    public var globalRefs: Int {
        globals.count
    }

    /// `mutableGlobals.count`.
    public var mutableGlobalRefs: Int {
        mutableGlobals.count
    }

    /// `statics.count`.
    public var staticRefs: Int {
        statics.count
    }

    /// `mutableStatics.count`.
    public var mutableStaticRefs: Int {
        mutableStatics.count
    }

    /// `singletons.count`.
    public var singletonRefs: Int {
        singletons.count
    }
}
