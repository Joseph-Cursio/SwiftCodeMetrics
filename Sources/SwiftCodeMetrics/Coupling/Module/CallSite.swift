//
//  CallSite.swift
//  SwiftCodeMetrics
//
//  One call with its key, before sites are grouped.
//

/// A keyed call site.
struct CallSite {
    /// The call key (Spec §7.5).
    let key: String
    /// The receiver kind.
    let receiver: ReceiverKind
    /// The callee's base name.
    let name: String
    /// The callee's start.
    let offset: Int
}
