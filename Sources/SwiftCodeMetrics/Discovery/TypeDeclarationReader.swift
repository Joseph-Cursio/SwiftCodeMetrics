//
//  TypeDeclarationReader.swift
//  SwiftCodeMetrics
//
//  Reads a type or extension declaration's own facts (Spec §9.1, §9.4):
//  its inheritance clause, stored properties, cases, attributes and the
//  type names outside member bodies.
//

import SwiftSyntax

/// Reads the declaration-level facts of a type or extension.
enum TypeDeclarationReader {
    /// The facts of `node`, whose name or extended type is `writtenName`.
    static func read(_ node: some DeclGroupSyntax, writtenName: String) -> TypeDeclarationFacts {
        var reader = TypeDeclarationAccumulator()
        reader.readInheritance(node.inheritanceClause)
        let genericClause = Syntax(node).asProtocol(WithGenericParametersSyntax.self)?.genericParameterClause
        for parameter in genericClause?.parameters ?? [] {
            if let constraint = parameter.inheritedType {
                reader.readGenericConstraint(constraint)
            }
        }
        if let whereClause = node.genericWhereClause {
            reader.collect(Syntax(whereClause), kind: .constraint, isWeakOrUnowned: false)
        }
        reader.readMembers(node.memberBlock.members)
        let ownAttributes = customAttributes(node.attributes)
        return TypeDeclarationFacts(
            range: ByteRange(
                start: node.positionAfterSkippingLeadingTrivia.utf8Offset,
                end: node.endPositionBeforeTrailingTrivia.utf8Offset
            ),
            writtenName: writtenName,
            whereClause: node.genericWhereClause.map { CanonicalText.render($0) },
            isConstrained: node.genericWhereClause != nil || Self.hasGenericArguments(node),
            customAttributes: ownAttributes,
            attachedAttributeNames: attributeNames(node.attributes) + reader.memberAttributes,
            inherited: reader.inherited,
            caseNames: reader.caseNames,
            storedProperties: reader.storedProperties,
            hasInstanceMembers: reader.hasInstanceMembers,
            typeNames: reader.typeNames
        )
    }

    /// Whether an extension's extended type binds generic arguments,
    /// `extension Box<Int>` (SE-0361): a same-type constraint.
    private static func hasGenericArguments(_ node: some DeclGroupSyntax) -> Bool {
        guard let extended = node.as(ExtensionDeclSyntax.self)?.extendedType else {
            return false
        }
        return extended.tokens(viewMode: .sourceAccurate).contains { token in
            token.tokenKind == .leftAngle || token.tokenKind == .leftSquare || token.tokenKind == .postfixQuestionMark
        }
    }

    /// Every attribute name, any case, for matching module macros:
    /// `@registerAll` can name an attached macro the module declares.
    static func attributeNames(_ attributes: AttributeListSyntax) -> [String] {
        SyntaxFacts.attributes(attributes).map(\.attributeName.trimmedDescription)
    }

    /// Attribute names that are not built in: written with an uppercase
    /// first letter, such as `@MainActor`, `@Observable` or a wrapper.
    /// Attributes inside `#if` clauses count, as every clause is walked (Spec §2.6).
    static func customAttributes(_ attributes: AttributeListSyntax) -> [String] {
        SyntaxFacts.attributes(attributes).compactMap { attribute in
            let name = attribute.attributeName.trimmedDescription
            return name.first?.isUppercase == true ? name : nil
        }
    }
}
