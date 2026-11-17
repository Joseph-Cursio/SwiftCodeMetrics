//
//  CaseListSummary.swift
//  SwiftCodeMetrics
//
//  What the decision count found in one switch case list.
//

/// Counted arms and the decisions inside them.
struct CaseListSummary {
    /// Arms counted: every case except fallthrough-only ones.
    var arms = 0
    /// Decisions inside the cases.
    var items: [Increment] = []

    /// Arms plus decisions: how `#if` clauses in a case list compete.
    var value: Int {
        arms + items.reduce(0) { $0 + $1.amount }
    }

    /// Adds another summary's arms and items.
    mutating func add(_ other: Self) {
        arms += other.arms
        items += other.items
    }
}
