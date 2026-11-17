//
//  CallableParameter.swift
//  SwiftCodeMetrics
//
//  What the recursion check needs to know about one parameter (Spec §3.4
//  rule 4).
//

import SwiftSyntax

/// One parameter of a `func`, reduced to what label matching uses.
struct CallableParameter: Equatable {
    /// The external label, `_` when there is none.
    let label: String
    /// Whether it has a default value.
    let hasDefault: Bool
    /// Whether it is variadic.
    let isVariadic: Bool
    /// Whether its type is syntactically a function type.
    let isFunctionType: Bool

    /// Reads a parameter clause.
    static func parameters(of clause: FunctionParameterClauseSyntax) -> [Self] {
        clause.parameters.map { parameter in
            Self(
                label: parameter.firstName.text,
                hasDefault: parameter.defaultValue != nil,
                isVariadic: parameter.ellipsis != nil,
                isFunctionType: isFunctionType(parameter.type)
            )
        }
    }

    /// Whether `type` is a function type once attributes, specifiers,
    /// parentheses and optionality are removed.
    private static func isFunctionType(_ type: TypeSyntax) -> Bool {
        var current = type
        while true {
            if current.is(FunctionTypeSyntax.self) {
                return true
            }
            if let attributed = current.as(AttributedTypeSyntax.self) {
                current = attributed.baseType
            } else if let optional = current.as(OptionalTypeSyntax.self) {
                current = optional.wrappedType
            } else if let unwrapped = current.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
                current = unwrapped.wrappedType
            } else if let tuple = current.as(TupleTypeSyntax.self), tuple.elements.count == 1,
                      let element = tuple.elements.first, element.firstName == nil {
                current = element.type
            } else {
                return false
            }
        }
    }
}
