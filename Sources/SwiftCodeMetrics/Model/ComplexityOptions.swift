//
//  ComplexityOptions.swift
//  SwiftCodeMetrics
//
//  Options for the three complexity scores (Spec §13.1).
//

/// Options for cognitive complexity, the decision count and the
/// SwiftLint-compatible count.
public struct ComplexityOptions: Sendable, Hashable, Codable {
    /// SwiftLint's `ignores_case_statements`. Affects only the SwiftLint-compatible count.
    public var swiftLintIgnoresCaseStatements = false
    /// Adds a cognitive increment for direct recursion (Spec §3.4).
    public var detectRecursion = true
    /// Scores a lookup-table `switch` as one decision (Spec §4.2). Lint only:
    /// SwiftStats leaves it off and stores the raw count.
    public var decisionCountIgnoresTrivialSwitches = false
    /// Protocols whose `some P` result marks a function as a result-builder
    /// body (Spec §5). Matched by the last name component.
    public var opaqueResultBuilderProtocols: Set<String> = [
        "ChartContent", "Commands", "CustomizableToolbarContent", "MapContent", "Scene",
        "TableColumnContent", "TableRowContent", "ToolbarContent", "View", "Widget",
        "WidgetConfiguration"
    ]

    /// The defaults.
    public init() {
        // Every property has a default.
    }
}
