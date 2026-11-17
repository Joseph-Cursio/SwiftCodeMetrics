//
//  FunctionNames.swift
//  SwiftCodeMetrics
//
//  Readable record names: `loadConfig(from:attempt:)`, `subscript(_:).get`,
//  `body.get`.
//

import SwiftSyntax

/// Builds readable names.
enum FunctionNames {
    /// `name(label:label:)`.
    static func function(_ node: FunctionDeclSyntax) -> String {
        node.name.text + labels(node.signature.parameterClause.parameters.map(\.firstName.text))
    }

    /// `init(label:)` or `init?(label:)`.
    static func initializer(_ node: InitializerDeclSyntax) -> String {
        let labels = node.signature.parameterClause.parameters.map(\.firstName.text)
        return "init" + (node.optionalMark?.text ?? "") + Self.labels(labels)
    }

    /// `subscript(_:)`. A subscript parameter has an external label only
    /// when it is written with two names.
    static func subscriptDeclaration(_ node: SubscriptDeclSyntax) -> String {
        "subscript" + labels(node.parameterClause.parameters.map { $0.secondName == nil ? "_" : $0.firstName.text })
    }

    /// `(label:label:)`.
    private static func labels(_ labels: [String]) -> String {
        "(" + labels.map { $0 + ":" }.joined() + ")"
    }
}
