//
//  SelfReferences.swift
//  SwiftCodeMetrics
//
//  One function's resolved uses of its own type's members (Spec §9.3).
//

/// What one function touches and calls on its own type.
struct SelfReferences {
    /// Names that reach an own member as a value: attributes, computed
    /// properties and method references.
    var memberNames: Set<String> = []
    /// Calls of own members.
    var calls: Set<MemberCall> = []
    /// Names that reach a member of an in-module superclass.
    var inherited: Set<String> = []
    /// Names that reach member lookup but no declaration.
    var unresolved: Set<String> = []
    /// First components of key paths rooted at `Self` or the type's name.
    var keyPathMembers: Set<String> = []
    /// First components of rootless key paths.
    var rootlessKeyPaths: Set<String> = []
    /// Whether `self` is used as a whole value.
    var wholeSelf = false
    /// Whether `self[...]` is called.
    var selfSubscript = false

    /// The union of two functions' references.
    func merged(with other: Self) -> Self {
        var result = self
        result.memberNames.formUnion(other.memberNames)
        result.calls.formUnion(other.calls)
        result.inherited.formUnion(other.inherited)
        result.unresolved.formUnion(other.unresolved)
        result.keyPathMembers.formUnion(other.keyPathMembers)
        result.rootlessKeyPaths.formUnion(other.rootlessKeyPaths)
        result.wholeSelf = wholeSelf || other.wholeSelf
        result.selfSubscript = selfSubscript || other.selfSubscript
        return result
    }
}
