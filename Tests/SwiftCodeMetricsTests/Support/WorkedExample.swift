//
//  WorkedExample.swift
//  SwiftCodeMetricsTests
//
//  What the spec states for one function of a worked example (Spec §6).
//

/// The stated scores of one function in a fixture.
struct WorkedExample: CustomStringConvertible, Sendable {
    /// The fixture file.
    let fixture: String
    /// The record's readable name.
    let function: String
    /// The scores, as "C n D n SL n".
    let scores: ExpectedScores
    /// The cognitive table as "line rule amount" items, comma-separated;
    /// nil when the spec gives no table.
    let items: String?

    var description: String {
        "\(fixture) \(function)"
    }

    /// The table's items.
    var expectedItems: [ExpectedItem] {
        (items ?? "").split(separator: ",").compactMap { ExpectedItem(text: String($0)) }
    }

    /// Creates an example.
    init(fixture: String, function: String, scores: String, items: String?) {
        self.fixture = fixture
        self.function = function
        self.scores = ExpectedScores(scores)
        self.items = items
    }
}
