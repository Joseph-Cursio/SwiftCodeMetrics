//
//  AccessorOwner.swift
//  SwiftCodeMetrics
//
//  The property or subscript an explicit accessor belongs to.
//

import SwiftSyntax

/// What an accessor's record takes from its property or subscript.
struct AccessorOwner {
    /// `value` for a property, `subscript(_:)` for a subscript.
    let name: String
    /// The property's key text; empty for a subscript, whose key is the context.
    let declaration: String
    /// Whether the property is `private` or `fileprivate`.
    let isFileScoped: Bool
    /// The property's or subscript's attributes.
    let attributes: [AttributeListSyntax]
    /// The property's type or the subscript's result type.
    let resultType: TypeSyntax?

    /// Finds the owner of `accessor`.
    init(_ accessor: AccessorDeclSyntax) {
        let block = accessor.parent?.parent?.as(AccessorBlockSyntax.self)
        if let binding = block?.parent?.as(PatternBindingSyntax.self) {
            let variable = SyntaxFacts.variable(of: binding)
            name = CanonicalText.render(binding.pattern)
            declaration = DeclarationRenderer.property(binding, modifiers: variable?.modifiers)
            isFileScoped = variable.map { SyntaxFacts.isFileScoped($0.modifiers) } ?? false
            attributes = variable.map { [$0.attributes] } ?? []
            resultType = binding.typeAnnotation?.type
        } else if let subscriptDecl = block?.parent?.as(SubscriptDeclSyntax.self) {
            name = FunctionNames.subscriptDeclaration(subscriptDecl)
            declaration = ""
            isFileScoped = false
            attributes = [subscriptDecl.attributes]
            resultType = subscriptDecl.returnClause.type
        } else {
            name = "accessor"
            declaration = ""
            isFileScoped = false
            attributes = []
            resultType = nil
        }
    }
}
