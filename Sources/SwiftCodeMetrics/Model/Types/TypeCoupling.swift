//
//  TypeCoupling.swift
//  SwiftCodeMetrics
//
//  One edge of the type graph (Spec §9.4, §10.3, §13.5).
//

/// A `ce` edge from one module type to another.
public struct TypeCoupling: Sendable, Codable, Hashable {
    private enum CodingKeys: String, CodingKey {
        case isWeakOrUnowned
        case kinds
        case provenance
        case resolution
        case source
        case target
        case targetClass
        case usr
    }

    /// The type that names the target.
    public var source: TypeKey
    /// The type it names.
    public var target: TypeKey
    /// The kinds of reference that produced the edge.
    public var kinds: Set<EdgeKind>
    /// Whether every stored property behind a `storedProperty` kind is `weak` or `unowned`.
    public var isWeakOrUnowned: Bool
    /// How the target is classified for the `ce` split.
    public var targetClass: TargetClass?
    /// Where the edge came from.
    public var provenance: Provenance
    /// How sure the target is.
    public var resolution: Resolution
    /// The target's USR, filled by an index collector only.
    public var usr: String?

    /// Creates an edge.
    public init(
        source: TypeKey,
        target: TypeKey,
        kinds: Set<EdgeKind>,
        isWeakOrUnowned: Bool,
        targetClass: TargetClass?,
        provenance: Provenance,
        resolution: Resolution,
        usr: String? = nil
    ) {
        self.source = source
        self.target = target
        self.kinds = kinds
        self.isWeakOrUnowned = isWeakOrUnowned
        self.targetClass = targetClass
        self.provenance = provenance
        self.resolution = resolution
        self.usr = usr
    }

    /// Encodes the kinds sorted, so stored edges are stable.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(source, forKey: .source)
        try container.encode(target, forKey: .target)
        try container.encode(kinds.sorted { $0.rawValue < $1.rawValue }, forKey: .kinds)
        try container.encode(isWeakOrUnowned, forKey: .isWeakOrUnowned)
        try container.encodeIfPresent(targetClass, forKey: .targetClass)
        try container.encode(provenance, forKey: .provenance)
        try container.encode(resolution, forKey: .resolution)
        try container.encodeIfPresent(usr, forKey: .usr)
    }
}
