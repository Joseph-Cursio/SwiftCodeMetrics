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
    /// Instance methods of the in-module superclasses.
    let inheritedMethods: Set<MemberCall>
    /// Inherited names whose nearest declaration up the chain is a stored
    /// instance property, not a computed override of one.
    let inheritedStorage: Set<String>

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

    /// Whether an inherited use reads storage: a read whose nearest
    /// declaration is a stored property, or a call of a stored closure that
    /// no inherited method with those labels takes.
    func readsInheritedStorage(_ name: String, call: MemberCall?) -> Bool {
        if let call, inheritedMethods.contains(call) {
            return false
        }
        return inheritedStorage.contains(name)
    }

    /// Whether a call reaches an inherited property: `self.onTap()` where
    /// `onTap` is a superclass's stored closure and the type has only
    /// `onTap(count:)`. A call matching an own method's labels reaches it.
    func reachesInheritedProperty(callOf call: MemberCall) -> Bool {
        reachesInheritedProperty(call.name) && methods.contains(call) == false
    }
}
