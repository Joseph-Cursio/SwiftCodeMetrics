//
//  CohesionNullReason.swift
//  SwiftCodeMetrics
//
//  Why LCOM4 is not defined (Spec §9.3).
//

/// The reasons `lcom4` is nil. When several hold, the first in the order
/// notApplicableKind, noStoredProperties, fewerThanTwoMembers, noStateUse wins.
public enum CohesionNullReason: String, Sendable, Codable, Hashable {
    /// |M| < 2.
    case fewerThanTwoMembers = "fewer_than_two_members"
    /// Every component is attribute-free.
    case noStateUse = "no_state_use"
    /// No stored properties, |A| = 0.
    case noStoredProperties = "no_stored_properties"
    /// An enum, protocol or extension group.
    case notApplicableKind = "not_applicable_kind"
}
