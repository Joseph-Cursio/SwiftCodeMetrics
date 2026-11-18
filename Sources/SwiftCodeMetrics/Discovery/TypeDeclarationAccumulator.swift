//
//  TypeDeclarationAccumulator.swift
//  SwiftCodeMetrics
//
//  The state of one TypeDeclarationReader pass over a member list: it
//  descends into `#if` clauses but never into members' bodies or nested
//  types.
//

import SwiftSyntax

/// Collects a declaration's inheritance, cases, stored properties and type names.
struct TypeDeclarationAccumulator {
    /// The inheritance clause.
    private(set) var inherited: [RawInherited] = []
    /// Enum case names.
    private(set) var caseNames: [String] = []
    /// Stored instance properties.
    private(set) var storedProperties: [StoredPropertyFact] = []
    /// Whether some member other than a nested type is an instance member.
    private(set) var hasInstanceMembers = false
    /// Type names, tagged with their edge kinds.
    private(set) var typeNames: [RawTypeName] = []
    /// Every attribute name on members.
    private(set) var memberAttributes: [String] = []

    /// `P & Q` as `P` and `Q`; `@unchecked P` as `P`; `~Copyable` as nothing.
    private static func split(_ type: TypeSyntax) -> [TypeSyntax] {
        if let attributed = type.as(AttributedTypeSyntax.self) {
            return split(attributed.baseType)
        }
        if let composition = type.as(CompositionTypeSyntax.self) {
            return composition.elements.flatMap { split($0.type) }
        }
        if type.is(SuppressedTypeSyntax.self) {
            return []
        }
        return [type]
    }

    /// Each binding's type as written: in `var a, b: Int`, `a` shares the
    /// annotation written after it.
    private static func sharedAnnotations(_ bindings: [PatternBindingSyntax]) -> [String?] {
        var shared: [String?] = []
        var next: String?
        for binding in bindings.reversed() {
            if let annotation = binding.typeAnnotation {
                next = annotation.type.trimmedDescription
            } else if binding.initializer != nil {
                next = nil
            }
            let own = binding.typeAnnotation?.type.trimmedDescription
            shared.insert(own ?? (binding.initializer == nil ? next : nil), at: 0)
        }
        return shared
    }

    /// The typed `throws(E)` types of a requirement's accessors: `{ get throws(E) }`.
    private static func accessorThrownTypes(_ block: AccessorBlockSyntax?) -> [Syntax] {
        guard case .accessors(let accessors)? = block?.accessors else {
            return []
        }
        return accessors.flatMap { CouplingHead.thrownType($0.effectSpecifiers?.throwsClause) }
    }

    /// The inheritance clause: names for conformances, and type names, each
    /// tagged with its entry so generic arguments take the entry's kind.
    mutating func readInheritance(_ clause: InheritanceClauseSyntax?) {
        for entry in clause?.inheritedTypes ?? [] {
            for type in Self.split(entry.type) {
                inherited.append(RawInherited(name: CanonicalText.render(type), type: TypeSpelling.spelled(type)))
                let first = typeNames.count
                collect(Syntax(type), kind: .inheritance, isWeakOrUnowned: false)
                for index in typeNames.indices.dropFirst(first) {
                    typeNames[index].inheritanceEntry = inherited.count - 1
                }
            }
        }
    }

    /// The member list, descending into `#if` clauses.
    mutating func readMembers(_ members: MemberBlockItemListSyntax) {
        for item in members {
            read(item.decl)
        }
    }

    /// Type names under `node`, tagged with `kind`.
    mutating func collect(_ node: Syntax, kind: EdgeKind, isWeakOrUnowned: Bool) {
        collect(node, kind: kind, isWeakOrUnowned: isWeakOrUnowned, excluding: [])
    }

    /// Type names under `node`, tagged with `kind`, leaving out names rooted
    /// at a declaration's own generic parameters.
    mutating func collect(_ node: Syntax, kind: EdgeKind, isWeakOrUnowned: Bool, excluding generics: Set<String>) {
        let collector = ReferenceCollector(edgeKind: kind)
        collector.walk(node)
        typeNames += collector.typeNames.compactMap { name in
            if let root = name.type.components.first, name.type.moduleSelector == nil, generics.contains(root) {
                return nil
            }
            var tagged = name
            tagged.isWeakOrUnowned = isWeakOrUnowned
            return tagged
        }
    }

    /// One member declaration.
    private mutating func read(_ decl: DeclSyntax) {
        if let ifConfig = decl.as(IfConfigDeclSyntax.self) {
            for clause in ifConfig.clauses {
                if case .decls(let nested)? = clause.elements {
                    readMembers(nested)
                }
            }
            return
        }
        guard decl.isProtocol(DeclGroupSyntax.self) == false else {
            return
        }
        if let attributed = decl.asProtocol(WithAttributesSyntax.self) {
            memberAttributes += TypeDeclarationReader.attributeNames(attributed.attributes)
        }
        if let variable = decl.as(VariableDeclSyntax.self) {
            readVariable(variable)
        } else if let cases = decl.as(EnumCaseDeclSyntax.self) {
            readCases(cases)
        } else if let alias = decl.as(TypeAliasDeclSyntax.self) {
            let generics = Set(TypeSpelling.names(of: alias.genericParameterClause))
            collect(Syntax(alias.initializer.value), kind: .typealias, isWeakOrUnowned: false, excluding: generics)
        } else if let associated = decl.as(AssociatedTypeDeclSyntax.self) {
            readAssociatedType(associated)
        } else if decl.is(MacroExpansionDeclSyntax.self) == false,
                  let modifiers = decl.asProtocol(WithModifiersSyntax.self)?.modifiers {
            // Functions, initialisers, deinitialisers and subscripts; a
            // freestanding macro such as `#warning` is none of them.
            hasInstanceMembers = hasInstanceMembers || SyntaxFacts.isTypeLevel(modifiers) == false
            readRequirement(decl)
        }
    }

    /// A requirement's signature: a func, init or subscript with no body
    /// has no record to carry its types (Spec §9.4 member signatures).
    private mutating func readRequirement(_ decl: DeclSyntax) {
        var parts: [Syntax] = []
        var generics: GenericParameterClauseSyntax?
        if let function = decl.as(FunctionDeclSyntax.self), function.body == nil {
            generics = function.genericParameterClause
            parts = CouplingHead.signature(of: function.signature.parameterClause.parameters)
                + CouplingHead.signature(
                    generics: function.genericParameterClause,
                    result: function.signature.returnClause?.type,
                    whereClause: function.genericWhereClause
                ) + CouplingHead.thrownType(function.signature.effectSpecifiers?.throwsClause)
        } else if let initializer = decl.as(InitializerDeclSyntax.self), initializer.body == nil {
            generics = initializer.genericParameterClause
            parts = CouplingHead.signature(of: initializer.signature.parameterClause.parameters)
                + CouplingHead.signature(
                    generics: initializer.genericParameterClause,
                    result: nil,
                    whereClause: initializer.genericWhereClause
                ) + CouplingHead.thrownType(initializer.signature.effectSpecifiers?.throwsClause)
        } else if let subscriptDecl = decl.as(SubscriptDeclSyntax.self),
                  subscriptDecl.accessorBlock.map(SyntaxFacts.hasBody) != true {
            generics = subscriptDecl.genericParameterClause
            parts = CouplingHead.signature(of: subscriptDecl.parameterClause.parameters)
                + CouplingHead.signature(
                    generics: subscriptDecl.genericParameterClause,
                    result: subscriptDecl.returnClause.type,
                    whereClause: subscriptDecl.genericWhereClause
                ) + Self.accessorThrownTypes(subscriptDecl.accessorBlock)
        }
        let excluded = Set(TypeSpelling.names(of: generics))
        for part in parts {
            collect(part, kind: .signature, isWeakOrUnowned: false, excluding: excluded)
        }
    }

    /// A property requirement (`var x: T { get }`) has no body to carry its type.
    private mutating func readPropertyRequirements(_ variable: VariableDeclSyntax) {
        for binding in variable.bindings {
            guard let block = binding.accessorBlock, SyntaxFacts.hasBody(block) == false,
                  let annotation = binding.typeAnnotation else {
                continue
            }
            for part in [Syntax(annotation.type)] + Self.accessorThrownTypes(block) {
                collect(part, kind: .signature, isWeakOrUnowned: false)
            }
        }
    }

    /// An associated type's constraints.
    private mutating func readAssociatedType(_ associated: AssociatedTypeDeclSyntax) {
        if let clause = associated.inheritanceClause {
            collect(Syntax(clause), kind: .constraint, isWeakOrUnowned: false)
        }
        if let whereClause = associated.genericWhereClause {
            collect(Syntax(whereClause), kind: .constraint, isWeakOrUnowned: false)
        }
    }

    /// A `var` or `let` member: stored-property facts and type names.
    private mutating func readVariable(_ variable: VariableDeclSyntax) {
        let isTypeLevel = SyntaxFacts.isTypeLevel(variable.modifiers)
        hasInstanceMembers = hasInstanceMembers || isTypeLevel == false
        let isWeak = variable.modifiers.contains { modifier in
            modifier.name.tokenKind == .keyword(.weak) || modifier.name.tokenKind == .keyword(.unowned)
        }
        readPropertyRequirements(variable)
        let bindings = Array(variable.bindings).filter(MemberFacts.isStored)
        guard bindings.isEmpty == false else {
            return
        }
        let wrappers = TypeDeclarationReader.customAttributes(variable.attributes)
        for attribute in SyntaxFacts.attributes(variable.attributes)
        where attribute.attributeName.trimmedDescription.first?.isUppercase == true
            && CompilerAttributes.names.contains(attribute.attributeName.trimmedDescription) == false {
            collect(Syntax(attribute.attributeName), kind: .wrapper, isWeakOrUnowned: false)
        }
        let shared = Self.sharedAnnotations(bindings)
        for (position, binding) in bindings.enumerated() {
            if let annotation = binding.typeAnnotation {
                collect(Syntax(annotation.type), kind: .storedProperty, isWeakOrUnowned: isWeak)
            }
            if let initializer = binding.initializer {
                collect(Syntax(initializer.value), kind: .storedProperty, isWeakOrUnowned: isWeak)
            }
            guard isTypeLevel == false else {
                continue
            }
            for name in MemberFacts.names(in: binding.pattern) {
                storedProperties.append(StoredPropertyFact(
                    name: name,
                    isLet: variable.bindingSpecifier.tokenKind == .keyword(.let),
                    isLazy: variable.modifiers.contains { $0.name.tokenKind == .keyword(.lazy) },
                    isWeakOrUnowned: isWeak,
                    hasObservers: binding.accessorBlock != nil,
                    attributeNames: wrappers,
                    typeText: shared[position]
                ))
            }
        }
    }

    /// Enum cases: names and payload types.
    private mutating func readCases(_ cases: EnumCaseDeclSyntax) {
        for element in cases.elements {
            // `move(x:)` and `move(dx:)` are two cases.
            let labels = element.parameterClause.map { clause in
                "(" + clause.parameters.map { ($0.firstName.map(SyntaxFacts.name) ?? "_") + ":" }.joined() + ")"
            } ?? ""
            caseNames.append(SyntaxFacts.name(element.name) + labels)
            for parameter in element.parameterClause?.parameters ?? [] {
                collect(Syntax(parameter.type), kind: .casePayload, isWeakOrUnowned: false)
            }
        }
    }
}
