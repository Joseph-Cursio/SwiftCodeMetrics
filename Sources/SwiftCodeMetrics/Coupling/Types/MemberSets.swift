//
//  MemberSets.swift
//  SwiftCodeMetrics
//
//  The member names one type's cohesion uses are checked against
//  (Spec §9.3): own and inherited, split into properties and methods.
//

/// A type's own and inherited member names, for classifying uses.
struct MemberSets {
    /// Every own member name.
    let own: Set<String>
    /// Every member name of the in-module superclasses.
    let inherited: Set<String>
    /// Own instance properties, stored or computed.
    let ownProperties: Set<String>
    /// Instance properties of the in-module superclasses.
    let inheritedProperties: Set<String>
    /// Own stored instance properties.
    let stored: Set<String>
    /// Own instance methods, by base name and labels.
    let methods: Set<MemberCall>

    /// Where a `self.name` is declared, by name alone.
    func place(_ name: String) -> MemberPlace {
        if own.contains(name) {
            return .own
        }
        return inherited.contains(name) ? .inherited : .undeclared
    }

    /// Whether a read of `name` reaches an inherited property although the
    /// type declares methods by that name: `self.name` where a superclass
    /// has `var name` and the type has `name(for:)`.
    func reachesInheritedProperty(_ name: String) -> Bool {
        ownProperties.contains(name) == false && inheritedProperties.contains(name)
    }

    /// Whether a call reaches an inherited property: `self.onTap()` where
    /// `onTap` is a superclass's stored closure and the type has only
    /// `onTap(count:)`. A call matching an own method's labels reaches it.
    func reachesInheritedProperty(callOf call: MemberCall) -> Bool {
        reachesInheritedProperty(call.name) && methods.contains(call) == false
    }
}
