//
//  StoredPropertyFact.swift
//  SwiftCodeMetrics
//
//  One stored instance property (Spec §2.4, §9.1).
//

/// A stored instance property.
public struct StoredPropertyFact: Sendable, Codable, Hashable {
    /// Its name; one fact per identifier of a tuple pattern.
    public var name: String
    /// Declared with `let`.
    public var isLet: Bool
    /// Declared `lazy`.
    public var isLazy: Bool
    /// Declared `weak` or `unowned`.
    public var isWeakOrUnowned: Bool
    /// Has `willSet` or `didSet`.
    public var hasObservers: Bool
    /// Its custom attributes, such as property wrappers.
    public var attributeNames: [String]
    /// Its type annotation as written, if any.
    public var typeText: String?
}
