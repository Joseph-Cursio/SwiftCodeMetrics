//
//  RecursionMatcher.swift
//  SwiftCodeMetrics
//
//  Finds direct recursion by syntax alone (Spec §3.4): a bare, `self.` or
//  (in a static function) `Self.` call with the function's base name and
//  fitting labels, unless the body shadows the name.
//

import SwiftSyntax

/// Classifies calls inside one ordinary `func`.
struct RecursionMatcher {
    /// The function's base name.
    let baseName: String
    /// Whether the function is `static` or `class`.
    let isTypeLevel: Bool
    /// Its parameters.
    let parameters: [CallableParameter]
    /// Names the body or the parameter list declares.
    let shadowed: Set<String>

    /// A matcher for `function`, or nil for an operator function.
    init?(function: FunctionDeclSyntax, body: [Syntax]) {
        switch function.name.tokenKind {
        case .binaryOperator, .postfixOperator, .prefixOperator:
            return nil

        default:
            break
        }
        let clause = function.signature.parameterClause
        var declared = ShadowedNames.names(in: body)
        for parameter in clause.parameters {
            let internalName = parameter.secondName ?? parameter.firstName
            if internalName.tokenKind != .wildcard {
                declared.insert(internalName.text)
            }
        }
        self.baseName = function.name.text
        self.isTypeLevel = SyntaxFacts.isTypeLevel(function.modifiers)
        self.parameters = CallableParameter.parameters(of: clause)
        self.shadowed = declared
    }

    /// What `call` means for this function.
    func classify(_ call: FunctionCallExprSyntax) -> RecursionMatch? {
        let arguments = CallArgument.arguments(of: call)
        if let reference = call.calledExpression.as(DeclReferenceExprSyntax.self) {
            guard reference.baseName.text == baseName, shadowed.contains(baseName) == false else {
                return nil
            }
            return fits(arguments) ? .direct(reference.baseName) : nil
        }
        guard let access = call.calledExpression.as(MemberAccessExprSyntax.self),
              access.declName.baseName.text == baseName else {
            return nil
        }
        let anchor = access.declName.baseName
        switch receiver(of: access) {
        case .ownSelf:
            return fits(arguments) ? .direct(anchor) : nil

        case .other:
            return LabelMatcher.fits(arguments, parameters, strict: true) ? .possible(anchor) : nil
        }
    }

    /// Whether a member call goes to this function's own receiver.
    private func receiver(of access: MemberAccessExprSyntax) -> Receiver {
        guard let base = access.base?.as(DeclReferenceExprSyntax.self) else {
            return .other
        }
        switch base.baseName.tokenKind {
        case .keyword(.self):
            return .ownSelf

        case .keyword(.Self):
            return isTypeLevel ? .ownSelf : .other

        default:
            return .other
        }
    }

    /// Whether the labels fit by the ordinary rule.
    private func fits(_ arguments: [CallArgument]) -> Bool {
        LabelMatcher.fits(arguments, parameters, strict: false)
    }
}
