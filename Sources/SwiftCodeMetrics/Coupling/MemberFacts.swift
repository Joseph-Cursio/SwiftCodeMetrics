//
//  MemberFacts.swift
//  SwiftCodeMetrics
//
//  Reads a member block into member facts, looking through `#if`
//  (Spec §2.3, §2.4, §2.6).
//

import SwiftSyntax

/// Collects the members of one type or extension.
struct MemberFacts {
    /// The members found.
    private(set) var members: [MemberFact] = []
    /// The member typealiases found.
    private(set) var typealiases: [TypealiasFact] = []
    /// The associated types found.
    private(set) var associatedTypes: [String] = []

    /// The type's simple name, for the singleton test.
    private let typeName: String
    /// The lexical path members are declared in.
    private let typePath: [String]
    /// The declaring file.
    private let file: String
    /// The function that owns the type, when it is local.
    private let localTo: MemberKey?
    /// The module, which may qualify the type's name in its own initialiser.
    private let module: String

    /// Reads `block`.
    init(
        _ block: MemberBlockSyntax,
        typeName: String,
        typePath: [String],
        file: String,
        localTo: MemberKey?,
        module: String
    ) {
        self.module = module
        self.typeName = typeName
        self.typePath = typePath
        self.file = file
        self.localTo = localTo
        read(block.members)
    }

    /// A typealias fact.
    static func typealiasFact(
        _ alias: TypeAliasDeclSyntax,
        typePath: [String],
        file: String,
        localTo: MemberKey?
    ) -> TypealiasFact {
        let target = alias.initializer.value
        return TypealiasFact(
            name: SyntaxFacts.name(alias.name),
            target: TypeSpelling.spelled(target),
            closure: TypeSpelling.closureShape(target),
            typePath: typePath,
            file: file,
            isFileScoped: SyntaxFacts.isFileScoped(alias.modifiers),
            genericParameters: TypeSpelling.names(of: alias.genericParameterClause),
            localTo: localTo
        )
    }

    /// Whether a binding has storage: no accessors, or observers only (Spec §2.4).
    static func isStored(_ binding: PatternBindingSyntax) -> Bool {
        guard let block = binding.accessorBlock else {
            return true
        }
        guard case .accessors(let accessors) = block.accessors else {
            return false
        }
        return accessors.allSatisfy { accessor in
            let specifier = accessor.accessorSpecifier.tokenKind
            return specifier == .keyword(.willSet) || specifier == .keyword(.didSet)
        }
    }

    /// The identifiers a pattern binds.
    static func names(in pattern: PatternSyntax) -> [String] {
        if let identifier = pattern.as(IdentifierPatternSyntax.self) {
            return [SyntaxFacts.name(identifier.identifier)]
        }
        if let tuple = pattern.as(TuplePatternSyntax.self) {
            return tuple.elements.flatMap { names(in: $0.pattern) }
        }
        return []
    }

    /// Whether `value` is `T(...)`, `T.init(...)`, `Self(...)` or `.init(...)` (Spec §8.2).
    private static func initializesOwnType(_ value: ExprSyntax?, typePath: [String]) -> Bool {
        guard let call = value?.as(FunctionCallExprSyntax.self) else {
            return false
        }
        var callee = call.calledExpression
        if let access = callee.as(MemberAccessExprSyntax.self),
           access.declName.baseName.tokenKind == .keyword(.`init`) {
            guard let base = access.base else {
                return true
            }
            callee = base
        }
        if callee.as(DeclReferenceExprSyntax.self)?.baseName.tokenKind == .keyword(.Self) {
            return true
        }
        // `T(...)`, or `Outer.T(...)` naming the type by any suffix of its path.
        guard let (names, _) = CalleeReader.dottedNames(callee) else {
            return false
        }
        // The path is prefixed with the module, so `Lib.Manager()` matches too.
        return names.count <= typePath.count && Array(typePath.suffix(names.count)) == names
    }

    /// Reads one member list, descending into `#if` clauses.
    private mutating func read(_ items: MemberBlockItemListSyntax) {
        for item in items {
            read(item.decl)
        }
    }

    /// Reads one member declaration.
    private mutating func read(_ decl: DeclSyntax) {
        if let ifConfig = decl.as(IfConfigDeclSyntax.self) {
            readClauses(ifConfig)
        } else if let variable = decl.as(VariableDeclSyntax.self) {
            readVariable(variable)
        } else if let cases = decl.as(EnumCaseDeclSyntax.self) {
            readCases(cases)
        } else if let alias = decl.as(TypeAliasDeclSyntax.self) {
            typealiases.append(Self.typealiasFact(alias, typePath: typePath, file: file, localTo: localTo))
        } else if let associated = decl.as(AssociatedTypeDeclSyntax.self) {
            associatedTypes.append(SyntaxFacts.name(associated.name))
        } else {
            readCallable(decl)
        }
    }

    /// Reads the declarations of every `#if` clause.
    private mutating func readClauses(_ ifConfig: IfConfigDeclSyntax) {
        for clause in ifConfig.clauses {
            if case .decls(let nested)? = clause.elements {
                read(nested)
            }
        }
    }

    /// Reads a function, initialiser or subscript; ignores anything else.
    private mutating func readCallable(_ decl: DeclSyntax) {
        if let function = decl.as(FunctionDeclSyntax.self) {
            add(SyntaxFacts.name(function.name), function.modifiers, .function)
            members[members.count - 1].labels = function.signature.parameterClause.parameters.map(\.firstName.text)
        } else if let initializer = decl.as(InitializerDeclSyntax.self) {
            add("init", initializer.modifiers, .initializer)
        } else if let subscriptDecl = decl.as(SubscriptDeclSyntax.self) {
            add("subscript", subscriptDecl.modifiers, .subscriptMember)
        }
    }

    /// Reads each element of an enum case declaration.
    private mutating func readCases(_ cases: EnumCaseDeclSyntax) {
        for element in cases.elements {
            members.append(MemberFact(
                name: SyntaxFacts.name(element.name),
                isTypeLevel: true,
                kind: .enumCase,
                isStoredVar: false,
                isSingletonCandidate: false
            ))
        }
    }

    /// Reads each binding of a variable declaration.
    private mutating func readVariable(_ variable: VariableDeclSyntax) {
        let isTypeLevel = SyntaxFacts.isTypeLevel(variable.modifiers)
        let isVar = variable.bindingSpecifier.tokenKind == .keyword(.var)
        for binding in variable.bindings {
            let isStored = Self.isStored(binding)
            let isSingleton = isTypeLevel && isStored
                && Self.initializesOwnType(binding.initializer?.value, typePath: [module] + typePath)
            for name in Self.names(in: binding.pattern) {
                members.append(MemberFact(
                    name: name,
                    isTypeLevel: isTypeLevel,
                    kind: isStored ? .storedProperty : .computedProperty,
                    isStoredVar: isStored && isVar,
                    isSingletonCandidate: isSingleton
                ))
            }
        }
    }

    /// Adds a member with no storage.
    private mutating func add(_ name: String, _ modifiers: DeclModifierListSyntax, _ kind: MemberKind) {
        members.append(MemberFact(
            name: name,
            isTypeLevel: SyntaxFacts.isTypeLevel(modifiers),
            kind: kind,
            isStoredVar: false,
            isSingletonCandidate: false
        ))
    }
}
