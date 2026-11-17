//
//  Increment.swift
//  SwiftCodeMetrics
//
//  One line of a score's breakdown (Spec §13.2, §13.3). The amounts of one
//  metric's items always sum to that metric's score.
//

/// One contribution to a complexity score.
public struct Increment: Sendable, Codable, Hashable {
    /// The score an item belongs to.
    public enum Metric: String, Sendable, Codable {
        /// Cognitive complexity (C).
        case cognitive
        /// The decision count (D).
        case decision
        /// The SwiftLint-compatible count (SL).
        case swiftLint = "swift_lint"
    }

    /// The construct that produced an item. Shared cases are used by every
    /// metric that counts the construct.
    public enum Rule: String, Sendable, Codable {
        /// A `catch` clause (shared).
        case catchClause = "catch_clause"
        /// Extra elements of a condition list (D): elements minus 1.
        case conditionElement = "condition_element"
        /// A condition list with two or more elements (C).
        case conditionList = "condition_list"
        /// A `#if` inside a body (C).
        case conditionalCompilation = "conditional_compilation"
        /// A `#elseif` or `#else` inside a body (C).
        case conditionalCompilationElse = "conditional_compilation_else"
        /// An `else` of an `if` (C).
        case elseClause = "else_clause"
        /// An `else if` (shared).
        case elseIf = "else_if"
        /// A `fallthrough` that is not its case's only statement (C).
        case fallthroughJump = "fallthrough_jump"
        /// A `fallthrough` (SL): −1.
        case fallthroughStatement = "fallthrough_statement"
        /// A refutable `for case` pattern (D).
        case forCasePattern = "for_case_pattern"
        /// A `guard` (shared).
        case guardStatement = "guard_statement"
        /// An `if` (shared).
        case ifStatement = "if_statement"
        /// A labelled `break` or `continue` (C).
        case labeledJump = "labeled_jump"
        /// An `&&` or `||` (D).
        case logicalOperator = "logical_operator"
        /// A run of like logical operators (C).
        case logicalSequence = "logical_sequence"
        /// A `for`, `while` or `repeat` loop (shared).
        case loop
        /// A `??` (D).
        case nilCoalescing = "nil_coalescing"
        /// A call that might be recursion through another receiver (C, amount 0).
        case possibleRecursion = "possible_recursion"
        /// Direct recursion, once per function (C).
        case recursion
        /// A `case` or `default` (SL).
        case switchCase = "switch_case"
        /// Arms of a `switch` minus 1 (D).
        case switchArms = "switch_arms"
        /// A `switch` (C).
        case switchStatement = "switch_statement"
        /// A ternary (shared).
        case ternary
        /// A lookup-table `switch`, when `decisionCountIgnoresTrivialSwitches` is on (D).
        case trivialSwitch = "trivial_switch"
        /// A `where` on a case item, a `for` or a catch item (D).
        case whereClause = "where_clause"
    }

    /// The score this item belongs to.
    public let metric: Metric
    /// The construct.
    public let rule: Rule
    /// The item's total: −1 for `fallthroughStatement`, 0 only for `possibleRecursion`.
    public let amount: Int
    /// The nesting part of `amount`; non-zero only for cognitive structural items.
    public let nesting: Int
    /// The part of `nesting` that comes from enclosing closures (not `defer`).
    public let closureNesting: Int
    /// The start of the anchor token (Spec §13.3).
    public let utf8Offset: Int
    /// The anchor's line, when locations are known.
    public let line: Int?
    /// The anchor's column, when locations are known.
    public let column: Int?
}
