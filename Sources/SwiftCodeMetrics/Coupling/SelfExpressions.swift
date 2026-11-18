//
//  SelfExpressions.swift
//  SwiftCodeMetrics
//
//  Syntax questions the reference collector asks about `self` and dotted
//  expression candidates (Spec §7.3 step 4, §9.3).
//

import SwiftSyntax

/// Stateless facts about `self` uses and member chains.
enum SelfExpressions {
    /// How a `self` expression is used (Spec §9.3 rule 6).
    enum Use {
        /// A member access base, callee, capture, `T.self` or `\.self`.
        case other
        /// The base of `self[...]`.
        case subscriptBase
        /// The whole value.
        case whole
    }

    /// The use of one `self` reference.
    static func use(of node: DeclReferenceExprSyntax) -> Use {
        // `T.self` and `\.self` name a value or metatype, not this instance.
        if node.parent?.as(MemberAccessExprSyntax.self)?.declName.id == node.id
            || node.parent?.is(KeyPathPropertyComponentSyntax.self) == true {
            return .other
        }
        var child = Syntax(node)
        while let parent = child.parent,
              parent.is(OptionalChainingExprSyntax.self) || parent.is(ForceUnwrapExprSyntax.self) {
            child = parent
        }
        if let subscriptCall = child.parent?.as(SubscriptCallExprSyntax.self),
           subscriptCall.calledExpression.id == child.id {
            return .subscriptBase
        }
        if child.parent?.as(MemberAccessExprSyntax.self)?.base?.id == child.id
            || child.parent?.as(FunctionCallExprSyntax.self)?.calledExpression.id == child.id
            || isInCaptureClause(node) {
            return .other
        }
        return .whole
    }

    /// `Self.State(...)`: a candidate for the nested type it names.
    static func selfTypeCandidate(_ node: DeclReferenceExprSyntax, edgeKind: EdgeKind) -> RawTypeName? {
        let trailing = trailingMembers(after: node)
        guard trailing.isEmpty == false else {
            return nil
        }
        return RawTypeName(
            type: SpelledType(components: ["Self"], moduleSelector: nil),
            edgeKind: edgeKind,
            offset: node.positionAfterSkippingLeadingTrivia.utf8Offset,
            isCandidate: true,
            lookup: [],
            trailingMembers: trailing
        )
    }

    /// The uppercase member names after `node` in `node.B.C`: the nested
    /// type names an expression candidate may continue with.
    static func trailingMembers(after node: some SyntaxProtocol) -> [String] {
        var members: [String] = []
        var current = Syntax(node)
        // `Box<Int>.Item`: the specialisation is part of the base.
        if let specialized = current.parent?.as(GenericSpecializationExprSyntax.self),
           specialized.expression.id == current.id {
            current = Syntax(specialized)
        }
        while let access = current.parent?.as(MemberAccessExprSyntax.self), access.base?.id == current.id {
            let member = SyntaxFacts.name(access.declName.baseName)
            guard CalleeReader.startsUppercase(member) else {
                break
            }
            members.append(member)
            current = Syntax(access)
        }
        return members
    }
    /// Whether `expression` is `self`, `self?` or `self!`.
    static func isSelf(_ expression: ExprSyntax) -> Bool {
        if let chained = expression.as(OptionalChainingExprSyntax.self) {
            return isSelf(chained.expression)
        }
        if let forced = expression.as(ForceUnwrapExprSyntax.self) {
            return isSelf(forced.expression)
        }
        return expression.as(DeclReferenceExprSyntax.self)?.baseName.tokenKind == .keyword(.self)
    }
    /// Whether `node` sits in a closure's capture list.
    static func isInCaptureClause(_ node: some SyntaxProtocol) -> Bool {
        var current = node.parent
        while let ancestor = current {
            if ancestor.is(ClosureCaptureClauseSyntax.self) {
                return true
            }
            if ancestor.is(CodeBlockItemSyntax.self) || ancestor.is(ClosureExprSyntax.self) {
                return false
            }
            current = ancestor.parent
        }
        return false
    }
}
