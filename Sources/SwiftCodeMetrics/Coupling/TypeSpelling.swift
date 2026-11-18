//
//  TypeSpelling.swift
//  SwiftCodeMetrics
//
//  Reads type syntax as names: dotted components with generic arguments
//  stripped and sugar mapped (Spec §2.2, §7.3), and the closure shape of a
//  parameter type (Spec §8.3).
//

import SwiftSyntax

/// Names and shapes of type syntax.
enum TypeSpelling {
    /// The named type `type` spells, or nil for a function, tuple or other unnamed type.
    static func spelled(_ type: TypeSyntax) -> SpelledType? {
        if let wrapped = type.as(SomeOrAnyTypeSyntax.self) {
            return spelled(wrapped.constraint)
        }
        if let attributed = type.as(AttributedTypeSyntax.self) {
            return spelled(attributed.baseType)
        }
        if let identifier = type.as(IdentifierTypeSyntax.self) {
            // A placeholder (`[String: _]`, SE-0315) names no type.
            guard identifier.name.tokenKind != .wildcard else {
                return nil
            }
            return SpelledType(
                components: [SyntaxFacts.name(identifier.name)],
                moduleSelector: identifier.moduleSelector?.moduleName.text
            )
        }
        if let member = type.as(MemberTypeSyntax.self), let base = spelled(member.baseType) {
            return SpelledType(
                components: base.components + [SyntaxFacts.name(member.name)],
                moduleSelector: base.moduleSelector
            )
        }
        if type.is(ArrayTypeSyntax.self) {
            return SpelledType(components: ["Array"], moduleSelector: nil)
        }
        if type.is(DictionaryTypeSyntax.self) {
            return SpelledType(components: ["Dictionary"], moduleSelector: nil)
        }
        if type.is(OptionalTypeSyntax.self) || type.is(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
            return SpelledType(components: ["Optional"], moduleSelector: nil)
        }
        return nil
    }

    /// The named types an inheritance entry spells: one, or each member of
    /// a composition (`class Card: Base & Themed` names Base, then Themed).
    static func spelledMembers(_ type: TypeSyntax) -> [SpelledType] {
        if let composition = type.as(CompositionTypeSyntax.self) {
            return composition.elements.flatMap { spelledMembers($0.type) }
        }
        return spelled(type).map { [$0] } ?? []
    }

    /// Whether a parameter type is a closure, before typealias expansion.
    static func closureShape(_ type: TypeSyntax) -> ClosureShape {
        var current = type
        var isEscaping = false
        var isOptional = false
        while true {
            if current.is(FunctionTypeSyntax.self) {
                return .function(escaping: isEscaping || isOptional)
            }
            if let attributed = current.as(AttributedTypeSyntax.self) {
                isEscaping = isEscaping || attributed.attributes.contains { element in
                    element.as(AttributeSyntax.self)?.attributeName.trimmedDescription == "escaping"
                }
                current = attributed.baseType
            } else if let optional = current.as(OptionalTypeSyntax.self) {
                isOptional = true
                current = optional.wrappedType
            } else if let unwrapped = current.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
                isOptional = true
                current = unwrapped.wrappedType
            } else if let tuple = current.as(TupleTypeSyntax.self), tuple.elements.count == 1,
                      let element = tuple.elements.first, element.firstName == nil {
                current = element.type
            } else if let named = spelled(current),
                      current.is(IdentifierTypeSyntax.self) || current.is(MemberTypeSyntax.self) {
                return .named(named, escaping: isOptional || isEscaping)
            } else {
                return .other
            }
        }
    }

    /// Whether a parameter type is `inout`.
    static func isInout(_ type: TypeSyntax) -> Bool {
        guard let attributed = type.as(AttributedTypeSyntax.self) else {
            return false
        }
        return attributed.specifiers.contains { specifier in
            specifier.as(SimpleTypeSpecifierSyntax.self)?.specifier.tokenKind == .keyword(.inout)
        }
    }

    /// The named members of a composition `P & Q`, attributes unwrapped;
    /// empty for any other type.
    static func compositionMembers(_ type: TypeSyntax) -> [SpelledType] {
        if let attributed = type.as(AttributedTypeSyntax.self) {
            return compositionMembers(attributed.baseType)
        }
        guard let composition = type.as(CompositionTypeSyntax.self) else {
            return []
        }
        return composition.elements.compactMap { spelled($0.type) }
    }

    /// The names a generic parameter clause declares.
    static func names(of clause: GenericParameterClauseSyntax?) -> [String] {
        clause?.parameters.map { SyntaxFacts.name($0.name) } ?? []
    }
}
