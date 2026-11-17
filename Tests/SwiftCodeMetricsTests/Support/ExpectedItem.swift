//
//  ExpectedItem.swift
//  SwiftCodeMetricsTests
//
//  One line of a worked example's cognitive table.
//

import SwiftCodeMetrics

/// A cognitive item the spec's table lists.
struct ExpectedItem: Equatable, CustomStringConvertible, Sendable {
    /// Rules by case name.
    private static let rules: [String: Increment.Rule] = {
        let all: [Increment.Rule] = [
            .catchClause, .conditionElement, .conditionList, .conditionalCompilation, .conditionalCompilationElse,
            .elseClause, .elseIf, .fallthroughJump, .fallthroughStatement, .forCasePattern, .guardStatement,
            .ifStatement, .labeledJump, .logicalOperator, .logicalSequence, .loop, .nilCoalescing,
            .possibleRecursion, .recursion, .switchCase, .switchArms, .switchStatement, .ternary,
            .trivialSwitch, .whereClause
        ]
        return Dictionary(uniqueKeysWithValues: all.map { ("\($0)", $0) })
    }()

    /// The anchor line, 1 being the declaration line.
    let line: Int
    /// The rule.
    let rule: Increment.Rule
    /// The amount.
    let amount: Int

    var description: String {
        "\(line) \(rule) +\(amount)"
    }

    /// Creates an item.
    init(line: Int, rule: Increment.Rule, amount: Int) {
        self.line = line
        self.rule = rule
        self.amount = amount
    }

    /// Reads "line rule amount", with the rule's case name.
    init?(text: String) {
        let words = text.split(separator: " ").map(String.init)
        let middle = words.dropFirst().dropLast()
        guard middle.count == 1,
              let lineNumber = words.first.flatMap({ Int($0) }),
              let total = words.last.flatMap({ Int($0) }),
              let name = middle.first,
              let parsed = Self.rules[name] else {
            return nil
        }
        self.init(line: lineNumber, rule: parsed, amount: total)
    }

    /// The cognitive items of a record, ignoring zero-amount ones.
    static func cognitive(of record: FunctionRecord) -> [Self] {
        record.complexity.items
            .filter { $0.metric == .cognitive && $0.amount != 0 }
            .map { Self(line: $0.line ?? 0, rule: $0.rule, amount: $0.amount) }
    }
}
