//
//  CouplingTally.swift
//  SwiftCodeMetrics
//
//  Distinct names collected for common coupling.
//

/// The distinct globals, statics and singletons seen so far.
struct CouplingTally {
    /// Globals.
    var globals: Set<String> = []
    /// Stored `var` globals.
    var mutableGlobals: Set<String> = []
    /// Statics of module types.
    var statics: Set<String> = []
    /// Stored `static var`s.
    var mutableStatics: Set<String> = []
    /// Singletons.
    var singletons: Set<String> = []

    /// The sorted result.
    var result: CommonCoupling {
        CommonCoupling(
            globals: globals.sorted(),
            mutableGlobals: mutableGlobals.sorted(),
            statics: statics.sorted(),
            mutableStatics: mutableStatics.sorted(),
            singletons: singletons.sorted()
        )
    }

    /// Adds a global.
    mutating func addGlobal(_ global: GlobalFact) {
        globals.insert(global.name)
        if global.isStoredVar {
            mutableGlobals.insert(global.name)
        }
    }

    /// Adds a static of `owner`; a stored static of a class or actor
    /// initialised by its own type is a singleton too.
    mutating func addStatic(owner: TypeKey, member: MemberFact, kind: TypeKind?) {
        let name = owner.path.joined(separator: ".") + "." + member.name
        statics.insert(name)
        if member.isStoredVar {
            mutableStatics.insert(name)
        }
        if member.isSingletonCandidate, kind == .class || kind == .actor {
            singletons.insert(name)
        }
    }
}
