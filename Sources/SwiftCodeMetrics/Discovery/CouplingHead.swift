//
//  CouplingHead.swift
//  SwiftCodeMetrics
//
//  What the file pass reads from a record's declaration for coupling: its
//  generic parameters, whether it is static, its signature types and its
//  parameters (Spec §8).
//

import SwiftSyntax

/// The declaration facts a record's coupling needs.
struct CouplingHead {
    /// A head with no declaration facts, for top-level code and deinitialisers.
    static let empty = Self(genericParameters: [], isTypeLevel: false, signature: [], parameters: nil)

    /// Generic parameters the declaration introduces.
    let genericParameters: [String]
    /// Whether it is `static` or `class`.
    let isTypeLevel: Bool
    /// Signature nodes whose type names count as `signature` references.
    let signature: [Syntax]
    /// The parameters, for the records that carry parameter counts.
    let parameters: FunctionParameterListSyntax?

    /// The signature nodes of a parameter list, without default values.
    static func signature(of parameters: FunctionParameterListSyntax) -> [Syntax] {
        parameters.map { Syntax($0.type) }
    }

    /// The type of a typed `throws(E)` clause, if any.
    static func thrownType(_ clause: ThrowsClauseSyntax?) -> [Syntax] {
        clause?.type.map { [Syntax($0)] } ?? []
    }

    /// The generic clause, return type and `where` clause of a declaration.
    static func signature(
        generics: GenericParameterClauseSyntax?,
        result: TypeSyntax?,
        whereClause: GenericWhereClauseSyntax?
    ) -> [Syntax] {
        [generics.map(Syntax.init), result.map(Syntax.init), whereClause.map(Syntax.init)].compactMap(\.self)
    }

    /// The same head with the accessor's typed `throws` type added.
    func adding(thrown clause: ThrowsClauseSyntax?) -> Self {
        Self(
            genericParameters: genericParameters,
            isTypeLevel: isTypeLevel,
            signature: signature + Self.thrownType(clause),
            parameters: parameters
        )
    }
}
