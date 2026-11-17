//
//  ResultBuilderHints.swift
//  SwiftCodeMetrics
//
//  Spec §5: a `…Builder` attribute, else a `some P` result whose protocol
//  is a known builder protocol.
//

import SwiftSyntax

/// Works out a function's `ResultBuilderHint`.
enum ResultBuilderHints {
    /// The hint for a body with these attribute lists and this result type.
    static func hint(
        attributes: [AttributeListSyntax],
        resultType: TypeSyntax?,
        protocols: Set<String>
    ) -> ResultBuilderHint? {
        for list in attributes {
            for element in list {
                if let name = builderName(element), name.hasSuffix("Builder") {
                    return .attribute(name)
                }
            }
        }
        guard let opaque = resultType?.as(SomeOrAnyTypeSyntax.self),
              opaque.someOrAnySpecifier.tokenKind == .keyword(.some) else {
            return nil
        }
        for name in constraintNames(opaque.constraint) where protocols.contains(name) {
            return .opaqueResult(name)
        }
        return nil
    }

    /// The last name component of an attribute, if it names a type.
    private static func builderName(_ element: AttributeListSyntax.Element) -> String? {
        guard case .attribute(let attribute) = element else {
            return nil
        }
        return lastComponent(attribute.attributeName)
    }

    /// The last name components of a constraint or a composition.
    private static func constraintNames(_ type: TypeSyntax) -> [String] {
        if let composition = type.as(CompositionTypeSyntax.self) {
            return composition.elements.compactMap { lastComponent($0.type) }
        }
        return lastComponent(type).map { [$0] } ?? []
    }

    /// `Builder` for `Builder` or `Module.Builder`.
    private static func lastComponent(_ type: TypeSyntax) -> String? {
        type.as(IdentifierTypeSyntax.self)?.name.text ?? type.as(MemberTypeSyntax.self)?.name.text
    }
}
