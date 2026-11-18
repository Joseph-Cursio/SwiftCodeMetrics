//
//  CalleeReader.swift
//  SwiftCodeMetrics
//
//  Reads the syntactic shape of calls and member accesses (Spec §7.5, §8.2).
//

import SwiftSyntax

/// Shape questions for call sites and member accesses.
enum CalleeReader {
    /// A call site, and the bare name it calls, if any.
    static func call(_ node: FunctionCallExprSyntax) -> (call: RawCall, bareReference: DeclReferenceExprSyntax?)? {
        let callee = strippedCallee(node.calledExpression)
        let labels = CallArgument.arguments(of: node).map { argument in
            if case .labeled(let label) = argument {
                return label
            }
            return "_"
        }
        let offset = callee.positionAfterSkippingLeadingTrivia.utf8Offset
        if let reference = callee.as(DeclReferenceExprSyntax.self) {
            return bareCall(reference, labels: labels, offset: offset)
        }
        guard let access = callee.as(MemberAccessExprSyntax.self) else {
            return nil
        }
        let call = RawCall(
            shape: shape(ofBase: access.base),
            name: SyntaxFacts.name(access.declName.baseName),
            labels: labels,
            offset: offset
        )
        return (call, nil)
    }

    /// `Base.member` on a named base or `Self`, or nil.
    static func memberRead(_ node: MemberAccessExprSyntax) -> RawMemberRead? {
        guard let base = node.base else {
            return nil
        }
        let offset = node.positionAfterSkippingLeadingTrivia.utf8Offset
        let member = SyntaxFacts.name(node.declName.baseName)
        if base.as(DeclReferenceExprSyntax.self)?.baseName.tokenKind == .keyword(.Self) {
            return RawMemberRead(
                base: [],
                baseIsSelfType: true,
                rootLookup: [],
                member: member,
                offset: offset
            )
        }
        guard let (components, root) = dottedNames(base) else {
            return nil
        }
        let lookup = rootLookup(root)
        return RawMemberRead(
            base: components,
            baseIsSelfType: false,
            rootLookup: lookup,
            member: member,
            offset: offset
        )
    }

    /// Whether a call sits in an expression pattern: `case .foo(let x):` tests a value (Spec §8.1).
    static func isInPattern(_ node: FunctionCallExprSyntax) -> Bool {
        var current = node.parent
        while let ancestor = current {
            if ancestor.is(ExpressionPatternSyntax.self) {
                return true
            }
            if ancestor.is(CodeBlockItemSyntax.self) || ancestor.is(ClosureExprSyntax.self) {
                return false
            }
            current = ancestor.parent
        }
        return false
    }

    /// Whether a name is the base of a member access or a generic
    /// specialisation, where an uppercase name is a type-name candidate.
    static func isTypePosition(_ node: DeclReferenceExprSyntax) -> Bool {
        if let access = node.parent?.as(MemberAccessExprSyntax.self) {
            return access.base?.id == node.id
        }
        return node.parent?.as(GenericSpecializationExprSyntax.self)?.expression.id == node.id
    }

    /// Whether a member access is a call's callee.
    static func isCallee(_ node: MemberAccessExprSyntax) -> Bool {
        var child = Syntax(node)
        while let parent = child.parent {
            if let call = parent.as(FunctionCallExprSyntax.self) {
                return call.calledExpression.id == child.id
            }
            guard parent.is(GenericSpecializationExprSyntax.self) || parent.is(OptionalChainingExprSyntax.self)
                || parent.is(ForceUnwrapExprSyntax.self) else {
                return false
            }
            child = parent
        }
        return false
    }

    /// Whether a name starts with an uppercase letter after any underscores (Spec §7.3).
    static func startsUppercase(_ name: String) -> Bool {
        name.drop { $0 == "_" }.first?.isUppercase == true
    }

    /// The names of a dotted chain `A.B.c`, and its root reference. A
    /// `Module::` selector on the root becomes a first component, and a
    /// `Self` root is kept as `Self`.
    static func dottedNames(_ expression: ExprSyntax) -> ([String], DeclReferenceExprSyntax)? {
        if let reference = expression.as(DeclReferenceExprSyntax.self) {
            switch reference.baseName.tokenKind {
            case .identifier:
                let name = SyntaxFacts.name(reference.baseName)
                // A `Module::` selector is kept as a `::Module` component, so a
                // type named like the module cannot shadow it.
                let marker = FunctionResolver.selectorMarker
                let selector = reference.moduleSelector.map { [marker + $0.moduleName.text] } ?? []
                return (selector + [name], reference)

            case .keyword(.Self):
                return (["Self"], reference)

            default:
                return nil
            }
        }
        if let access = expression.as(MemberAccessExprSyntax.self),
           let base = access.base,
           let (names, root) = dottedNames(base) {
            return (names + [SyntaxFacts.name(access.declName.baseName)], root)
        }
        if let specialized = expression.as(GenericSpecializationExprSyntax.self) {
            return dottedNames(specialized.expression)
        }
        return nil
    }

    /// An unqualified callee.
    private static func bareCall(
        _ reference: DeclReferenceExprSyntax,
        labels: [String],
        offset: Int
    ) -> (call: RawCall, bareReference: DeclReferenceExprSyntax?)? {
        switch reference.baseName.tokenKind {
        case .keyword(.Self):
            return (RawCall(shape: .selfType, name: "init", labels: labels, offset: offset), nil)

        case .identifier:
            let name = SyntaxFacts.name(reference.baseName)
            // `Swift::max(...)` is the same call as `Swift.max(...)`, with no lookup.
            if let module = reference.moduleSelector?.moduleName.text {
                let shape = CalleeShape.qualified(base: [FunctionResolver.selectorMarker + module], rootLookup: [])
                return (RawCall(shape: shape, name: name, labels: labels, offset: offset), reference)
            }
            let lookup = NameLookup.lookup(reference.baseName, from: reference)
            return (RawCall(shape: .bare(lookup: lookup), name: name, labels: labels, offset: offset), reference)

        case .dollarIdentifier(let name):
            return (RawCall(shape: .bare(lookup: [.local]), name: name, labels: labels, offset: offset), reference)

        default:
            return nil
        }
    }

    /// The receiver form of a member callee's base.
    private static func shape(ofBase base: ExprSyntax?) -> CalleeShape {
        guard let base else {
            return .implicitMember
        }
        let receiver = stripped(base, keywords: false)
        if let reference = receiver.as(DeclReferenceExprSyntax.self) {
            switch reference.baseName.tokenKind {
            case .keyword(.self):
                return .selfMember

            case .keyword(.Self):
                return .selfType

            default:
                break
            }
        }
        if receiver.is(SuperExprSyntax.self) {
            return .superMember
        }
        if stripped(base, keywords: true).is(FunctionCallExprSyntax.self) {
            return .chain
        }
        if let (names, root) = dottedNames(base) {
            return .qualified(base: names, rootLookup: rootLookup(root))
        }
        return .other
    }

    /// The lookup results of a dotted chain's root: none for a `Module::`
    /// selector or `Self`, which are not looked up.
    private static func rootLookup(_ root: DeclReferenceExprSyntax) -> [StoredLookupResult] {
        root.moduleSelector == nil ? NameLookup.lookup(root.baseName, from: root) : []
    }

    /// The callee without generic arguments, `?` and `!`.
    private static func strippedCallee(_ expression: ExprSyntax) -> ExprSyntax {
        var current = expression
        while true {
            if let specialized = current.as(GenericSpecializationExprSyntax.self) {
                current = specialized.expression
            } else if let chained = current.as(OptionalChainingExprSyntax.self) {
                current = chained.expression
            } else if let forced = current.as(ForceUnwrapExprSyntax.self) {
                current = forced.expression
            } else {
                return current
            }
        }
    }

    /// A base without `?` and `!`, and, when `keywords`, without `try`,
    /// `await`, `unsafe` and one-element parentheses too.
    private static func stripped(_ expression: ExprSyntax, keywords: Bool) -> ExprSyntax {
        var current = expression
        while true {
            if let chained = current.as(OptionalChainingExprSyntax.self) {
                current = chained.expression
            } else if let forced = current.as(ForceUnwrapExprSyntax.self) {
                current = forced.expression
            } else if keywords {
                let inner = ExpressionShape.unwrap(current)
                if inner.id == current.id {
                    return current
                }
                current = inner
            } else {
                return current
            }
        }
    }
}
