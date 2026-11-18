//
//  TypeEdges.swift
//  SwiftCodeMetrics
//
//  Collects one type's outgoing references by target (Spec §9.4): edge
//  kinds, weak stored properties, the own nesting family, and the platform,
//  external, unresolved and ambiguous names.
//

/// One type's references, grouped for `ce`.
struct TypeEdges {
    /// Edge kinds per module target outside the family.
    private(set) var kinds: [TypeKey: Set<EdgeKind>] = [:]
    /// Targets named by a strong stored property.
    private(set) var strongStored: Set<TypeKey> = []
    /// Targets of the own nesting family.
    private(set) var internalTargets: Set<TypeKey> = []
    /// Distinct `platform` names.
    private(set) var platformNames: Set<String> = []
    /// Distinct `external` names.
    private(set) var externalNames: Set<String> = []
    /// Distinct unresolved names.
    private(set) var unresolvedNames: Set<String> = []
    /// Distinct ambiguous names.
    private(set) var ambiguousNames: Set<String> = []

    /// The owner.
    let owner: TypeKey
    /// The owner's family root.
    let family: TypeKey

    /// Adds one reference with the kind it contributes.
    mutating func add(
        _ reference: TypeReference,
        kind: EdgeKind,
        isWeakOrUnowned: Bool,
        familyOf: (TypeKey) -> TypeKey
    ) {
        switch reference.bucket {
        case .module:
            guard let target = reference.target, target != owner else {
                return
            }
            if familyOf(target) == family {
                internalTargets.insert(target)
                return
            }
            kinds[target, default: []].insert(kind)
            if kind == .storedProperty, isWeakOrUnowned == false {
                strongStored.insert(target)
            }

        case .platform:
            // `Swift.Int`, `Int` and `Self` in `extension Int` are one platform name.
            platformNames.insert(reference.resolvedName ?? reference.spelling)

        case .external:
            externalNames.insert(reference.resolvedName ?? reference.spelling)

        case nil:
            if reference.resolution == .ambiguous {
                ambiguousNames.insert(reference.spelling)
            } else {
                unresolvedNames.insert(reference.spelling)
            }
        }
    }

    /// The edges, in target order.
    func edges(targetClass: (TypeKey) -> TargetClass) -> [TypeCoupling] {
        kinds.keys.sorted { $0.description < $1.description }.map { target in
            let targetKinds = kinds[target] ?? []
            return TypeCoupling(
                source: owner,
                target: target,
                kinds: targetKinds,
                isWeakOrUnowned: targetKinds.contains(.storedProperty) && strongStored.contains(target) == false,
                targetClass: targetClass(target),
                provenance: .syntax,
                resolution: .exact
            )
        }
    }
}
