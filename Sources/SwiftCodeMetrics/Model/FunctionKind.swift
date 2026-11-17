//
//  FunctionKind.swift
//  SwiftCodeMetrics
//
//  The kinds of scored body (Spec §2.1).
//

/// The kind of body a function record scores.
public enum FunctionKind: String, Sendable, Codable, CaseIterable {
    /// An explicit accessor: `get`, `set`, `willSet`, `didSet`, `_modify`, …
    case accessor
    /// The implicit getter of a computed property or local variable.
    case computedGetter = "computed_getter"
    /// A `deinit`.
    case deinitializer
    /// A `func`, including nested and operator functions.
    case function
    /// An `init`.
    case initializer
    /// A stored property's or global's initial value with non-zero C or D.
    case propertyInitializer = "property_initializer"
    /// The implicit getter of a subscript.
    case subscriptGetter = "subscript_getter"
    /// A file's top-level statements. File form only.
    case topLevelCode = "top_level_code"

    /// SwiftStats' `FunctionKind` raw value (Spec §2.1); nil for `.propertyInitializer`.
    public var swiftStatsKind: String? {
        switch self {
        case .accessor, .computedGetter:
            "accessor"

        case .deinitializer:
            "deinit"

        case .function:
            "func"

        case .initializer:
            "init"

        case .propertyInitializer:
            nil

        case .subscriptGetter:
            "subscript"

        case .topLevelCode:
            "topLevel"
        }
    }

    /// Whether SwiftLint's `cyclomatic_complexity` scores this kind.
    public var swiftLintScoresKind: Bool {
        self == .function || self == .initializer
    }
}
