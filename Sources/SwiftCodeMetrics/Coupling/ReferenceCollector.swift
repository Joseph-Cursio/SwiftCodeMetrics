//
//  ReferenceCollector.swift
//  SwiftCodeMetrics
//
//  The file pass over one function's own body (Spec §7.1, §8): call sites,
//  bare names, `Base.member` accesses and type names, each with its lookup
//  result. Closures fold in; nested functions, local types and default
//  arguments do not.
//

import SwiftSyntax

/// Collects one body's raw references.
final class ReferenceCollector: OwnBodyVisitor {
    /// Call sites.
    private(set) var calls: [RawCall] = []
    /// Bare names other than callees.
    private(set) var names: [RawName] = []
    /// Member accesses that are not callees.
    private(set) var memberReads: [RawMemberRead] = []
    /// Type names.
    private(set) var typeNames: [RawTypeName] = []
    /// Freestanding macro expansions.
    private(set) var macroExpansionCount = 0
    /// Uses of `self` for the cohesion graph.
    private(set) var cohesion = RawCohesionFacts()

    /// `signature` or `body`.
    private let edgeKind: EdgeKind
    /// Callee name references, so they are not also recorded as names.
    private var callees: Set<SyntaxIdentifier> = []

    /// Creates a collector that tags type names with `edgeKind`.
    init(edgeKind: EdgeKind) {
        self.edgeKind = edgeKind
        super.init()
    }

    // MARK: - Calls and names

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        guard CalleeReader.isInPattern(node) == false, let read = CalleeReader.call(node) else {
            return .visitChildren
        }
        calls.append(read.call)
        if let reference = read.bareReference {
            callees.insert(reference.id)
            if CalleeReader.startsUppercase(read.call.name) {
                var lookup: [StoredLookupResult] = []
                if case .bare(let found) = read.call.shape {
                    lookup = found
                }
                typeNames.append(RawTypeName(
                    type: SpelledType(
                        components: [read.call.name],
                        moduleSelector: reference.moduleSelector?.moduleName.text
                    ),
                    edgeKind: edgeKind,
                    offset: offset(reference),
                    isCandidate: true,
                    lookup: lookup
                ))
            }
        }
        return .visitChildren
    }

    override func visit(_ node: DeclReferenceExprSyntax) -> SyntaxVisitorContinueKind {
        if node.baseName.tokenKind == .keyword(.self) {
            noteSelf(node)
            return .visitChildren
        }
        // A member's name in `a.b` and a key-path component `\.b` name members
        // of another type, not unqualified values (Spec §7.2).
        guard callees.contains(node.id) == false, case .identifier = node.baseName.tokenKind,
              node.parent?.as(MemberAccessExprSyntax.self)?.declName.id != node.id,
              node.parent?.as(KeyPathPropertyComponentSyntax.self)?.declName.id != node.id else {
            return .visitChildren
        }
        let name = SyntaxFacts.name(node.baseName)
        let selector = node.moduleSelector?.moduleName.text
        let isTypePosition = CalleeReader.isTypePosition(node)
        let lookup = selector == nil ? NameLookup.lookup(node.baseName, from: node) : []
        if let selector {
            // `Lib::counter` reads like `Lib.counter`.
            memberReads.append(RawMemberRead(
                base: [selector],
                baseIsSelfType: false,
                rootLookup: [],
                member: name,
                offset: offset(node)
            ))
        } else {
            names.append(RawName(
                name: name,
                lookup: lookup,
                offset: offset(node),
                isTypePosition: isTypePosition,
                isCompound: node.argumentNames != nil,
                labels: node.argumentNames?.arguments.map { SyntaxFacts.name($0.name) } ?? []
            ))
        }
        addQualifiedCandidate(node, root: name)
        if isTypePosition, CalleeReader.startsUppercase(name) {
            typeNames.append(RawTypeName(
                type: SpelledType(components: [name], moduleSelector: selector),
                edgeKind: edgeKind,
                offset: offset(node),
                isCandidate: true,
                lookup: lookup
            ))
        }
        return .visitChildren
    }

    /// `Module.Type` in an expression: the type after a possible module
    /// qualifier, kept only if the module pass finds `Module` is a module (Spec §7.3 step 1).
    private func addQualifiedCandidate(_ node: DeclReferenceExprSyntax, root: String) {
        guard node.moduleSelector == nil, let access = node.parent?.as(MemberAccessExprSyntax.self),
              access.base?.id == node.id else {
            return
        }
        let member = SyntaxFacts.name(access.declName.baseName)
        guard CalleeReader.startsUppercase(member) else {
            return
        }
        typeNames.append(RawTypeName(
            type: SpelledType(components: [member], moduleSelector: root),
            edgeKind: edgeKind,
            offset: offset(access.declName),
            isCandidate: true,
            lookup: [],
            qualifierMustBeModule: true
        ))
    }

    override func visit(_ node: MemberAccessExprSyntax) -> SyntaxVisitorContinueKind {
        let isCallee = CalleeReader.isCallee(node)
        if isCallee == false, let read = CalleeReader.memberRead(node) {
            memberReads.append(read)
        }
        if isCallee == false, let base = node.base {
            // `self.f(y:)` keeps its labels, so it picks one overload.
            let labels = node.declName.argumentNames.map { names in
                "(" + names.arguments.map { SyntaxFacts.name($0.name) + ":" }.joined() + ")"
            } ?? ""
            let member = SyntaxFacts.name(node.declName.baseName) + labels
            if SelfExpressions.isSelf(base) {
                cohesion.selfMembers.append(member)
            } else if base.is(SuperExprSyntax.self) {
                cohesion.superMembers.append(member)
            }
        }
        return .visitChildren
    }

    // MARK: - Cohesion

    /// `if let a` and `guard let a` read the member `a` (Spec §9.3 rule 3).
    override func visit(_ node: OptionalBindingConditionSyntax) -> SyntaxVisitorContinueKind {
        if node.initializer == nil, let pattern = node.pattern.as(IdentifierPatternSyntax.self),
           pattern.identifier.identifier != nil {
            cohesion.shorthandBindings.append(RawName(
                name: SyntaxFacts.name(pattern.identifier),
                lookup: NameLookup.lookup(pattern.identifier, from: node),
                offset: offset(pattern),
                isTypePosition: false
            ))
        }
        return .visitChildren
    }

    /// A key path's root and first property component (Spec §9.3 rule 5).
    override func visit(_ node: KeyPathExprSyntax) -> SyntaxVisitorContinueKind {
        if case .property(let property)? = node.components.first?.component {
            let root = node.root.flatMap { TypeSpelling.spelled($0)?.components } ?? []
            cohesion.keyPaths.append(RawKeyPath(
                root: root,
                firstComponent: SyntaxFacts.name(property.declName.baseName)
            ))
        }
        return .visitChildren
    }

    /// A `self` that is not the base of a member access, the base of a
    /// subscript call, a callee or a capture is the whole value (rule 6).
    private func noteSelf(_ node: DeclReferenceExprSyntax) {
        switch SelfExpressions.use(of: node) {
        case .subscriptBase:
            cohesion.selfSubscriptUses += 1

        case .whole:
            cohesion.wholeSelfUses += 1

        case .other:
            break
        }
    }

    /// An attribute's name (`@escaping`, `@Sendable`) is not a type reference.
    override func visit(_ node: AttributeSyntax) -> SyntaxVisitorContinueKind {
        if let arguments = node.arguments {
            walk(arguments)
        }
        return .skipChildren
    }

    override func visit(_: MacroExpansionExprSyntax) -> SyntaxVisitorContinueKind {
        macroExpansionCount += 1
        return .visitChildren
    }

    override func visit(_: MacroExpansionDeclSyntax) -> SyntaxVisitorContinueKind {
        macroExpansionCount += 1
        return .visitChildren
    }

    // MARK: - Type names

    override func visit(_ node: IdentifierTypeSyntax) -> SyntaxVisitorContinueKind {
        addType(TypeSyntax(node))
        return .visitChildren
    }

    override func visit(_ node: MemberTypeSyntax) -> SyntaxVisitorContinueKind {
        addType(TypeSyntax(node))
        var base = node.baseType
        while let member = base.as(MemberTypeSyntax.self) {
            if let arguments = member.genericArgumentClause {
                walk(arguments)
            }
            base = member.baseType
        }
        if let identifier = base.as(IdentifierTypeSyntax.self) {
            if let arguments = identifier.genericArgumentClause {
                walk(arguments)
            }
        } else {
            // `[Item].Index`: the sugar is named by the member type; its element types count.
            for child in base.children(viewMode: .sourceAccurate) {
                walk(child)
            }
        }
        if let arguments = node.genericArgumentClause {
            walk(arguments)
        }
        return .skipChildren
    }

    override func visit(_ node: ArrayTypeSyntax) -> SyntaxVisitorContinueKind {
        addType(TypeSyntax(node))
        return .visitChildren
    }

    override func visit(_ node: DictionaryTypeSyntax) -> SyntaxVisitorContinueKind {
        addType(TypeSyntax(node))
        return .visitChildren
    }

    override func visit(_ node: OptionalTypeSyntax) -> SyntaxVisitorContinueKind {
        addType(TypeSyntax(node))
        return .visitChildren
    }

    override func visit(_ node: ImplicitlyUnwrappedOptionalTypeSyntax) -> SyntaxVisitorContinueKind {
        addType(TypeSyntax(node))
        return .visitChildren
    }

    /// Records a written type name.
    private func addType(_ type: TypeSyntax) {
        guard let spelled = TypeSpelling.spelled(type) else {
            return
        }
        typeNames.append(RawTypeName(
            type: spelled,
            edgeKind: edgeKind,
            offset: offset(type),
            isCandidate: false,
            lookup: []
        ))
    }

    /// The start of a node, without trivia.
    private func offset(_ node: some SyntaxProtocol) -> Int {
        node.positionAfterSkippingLeadingTrivia.utf8Offset
    }

    deinit {
        // Nothing to release beyond stored properties.
    }
}
