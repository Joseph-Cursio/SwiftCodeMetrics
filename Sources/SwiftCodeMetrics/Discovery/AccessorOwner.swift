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
    /// The property's or subscript's modifiers say `static` or `class`.
    let isTypeLevel: Bool
    /// The subscript, for an accessor of one.
    let subscriptDecl: SubscriptDeclSyntax?

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
            isTypeLevel = variable.map { SyntaxFacts.isTypeLevel($0.modifiers) } ?? false
            subscriptDecl = nil
        } else if let owningSubscript = block?.parent?.as(SubscriptDeclSyntax.self) {
            name = FunctionNames.subscriptDeclaration(owningSubscript)
            declaration = ""
            isFileScoped = false
            attributes = [owningSubscript.attributes]
            resultType = owningSubscript.returnClause.type
            isTypeLevel = SyntaxFacts.isTypeLevel(owningSubscript.modifiers)
            subscriptDecl = owningSubscript
        } else {
            name = "accessor"
            declaration = ""
            isFileScoped = false
            attributes = []
            resultType = nil
            isTypeLevel = false
            subscriptDecl = nil
        }
    }

    /// The coupling head of a subscript's records. Only one record per
    /// subscript carries its parameter counts (Spec §8.3).
    static func coupling(of node: SubscriptDeclSyntax, carriesParameters: Bool) -> CouplingHead {
        let parameters = node.parameterClause.parameters
        return CouplingHead(
            genericParameters: TypeSpelling.names(of: node.genericParameterClause),
            isTypeLevel: SyntaxFacts.isTypeLevel(node.modifiers),
            signature: CouplingHead.signature(of: parameters) + CouplingHead.signature(
                generics: node.genericParameterClause,
                result: node.returnClause.type,
                whereClause: node.genericWhereClause
            ),
            parameters: carriesParameters ? parameters : nil
        )
    }

    /// The coupling head of `accessor`: a subscript's first accessor with a
    /// body carries the subscript's parameters.
    func coupling(for accessor: AccessorDeclSyntax) -> CouplingHead {
        let thrown = accessor.effectSpecifiers?.throwsClause
        guard let subscriptDecl else {
            return CouplingHead(
                genericParameters: [],
                isTypeLevel: isTypeLevel,
                signature: resultType.map { [Syntax($0)] } ?? [],
                parameters: nil
            ).adding(thrown: thrown)
        }
        var first: AccessorDeclSyntax?
        if case .accessors(let accessors)? = subscriptDecl.accessorBlock?.accessors {
            first = accessors.first { $0.body != nil }
        }
        return Self.coupling(of: subscriptDecl, carriesParameters: first?.id == accessor.id).adding(thrown: thrown)
    }
}
