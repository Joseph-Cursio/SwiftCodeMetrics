//
//  FunctionCollector+Declarations.swift
//  SwiftCodeMetrics
//
//  The file pass's declarations (Spec §7.1): types, extensions, globals,
//  free functions, typealiases and imports.
//

import SwiftSyntax

extension FunctionCollector {
    /// Records a type declaration and opens its scope.
    func openType(_ node: some DeclGroupSyntax & NamedDeclSyntax, kind: TypeKind) {
        let lexical = lexicalPosition().enteringType()
        let name = SyntaxFacts.name(node.name)
        let path = lexical.typePath + [name]
        let genericClause = Syntax(node).asProtocol(WithGenericParametersSyntax.self)?.genericParameterClause
        var generics = TypeSpelling.names(of: genericClause)
        let primaryTypes = node.as(ProtocolDeclSyntax.self)?.primaryAssociatedTypeClause?.primaryAssociatedTypes
        generics += primaryTypes?.map { SyntaxFacts.name($0.name) } ?? []
        let facts = MemberFacts(
            node.memberBlock,
            typeName: name,
            typePath: path,
            file: context.file ?? "",
            localTo: lexical.localOwner,
            module: context.module
        )
        let isFileScoped = SyntaxFacts.isFileScoped(node.modifiers) || lexical.isFileScoped
        let inherited = node.inheritanceClause?.inheritedTypes.flatMap { TypeSpelling.spelledMembers($0.type) } ?? []
        declarations.types.append(TypeFact(
            path: path,
            extensionPathLength: lexical.extensionPathLength,
            localTo: lexical.localOwner,
            enclosingTypePath: lexical.enclosingTypePath,
            enclosingLocalOwner: lexical.enclosingLocalOwner,
            kind: kind,
            isFileScoped: isFileScoped,
            file: context.file ?? "",
            genericParameters: generics,
            associatedTypes: facts.associatedTypes,
            inherited: inherited,
            members: facts.members,
            typealiases: facts.typealiases,
            declaration: TypeDeclarationReader.read(node, writtenName: node.name.text)
        ))
        pushType(
            name: node.name.text,
            modifiers: node.modifiers,
            owner: node.id,
            genericParameters: generics + facts.associatedTypes
        )
    }

    /// Records an extension and opens its scope.
    func openExtension(_ node: ExtensionDeclSyntax) {
        if let extended = TypeSpelling.spelled(node.extendedType) {
            let facts = MemberFacts(
                node.memberBlock,
                typeName: extended.components.last ?? "",
                typePath: extended.extensionPath(in: context.module),
                file: context.file ?? "",
                localTo: nil,
                module: context.module
            )
            // Members of a `private extension` are file-private, its
            // typealiases included.
            let isFileScoped = SyntaxFacts.isFileScoped(node.modifiers)
            let typealiases = facts.typealiases.map { alias in
                var scoped = alias
                scoped.isFileScoped = alias.isFileScoped || isFileScoped
                return scoped
            }
            declarations.extensions.append(ExtensionDeclFact(
                extended: extended,
                members: facts.members,
                typealiases: typealiases,
                file: context.file ?? "",
                declaration: TypeDeclarationReader.read(
                    node,
                    writtenName: CanonicalText.render(node.extendedType)
                )
            ))
        }
        pushExtension(node)
    }

    /// Records a global's names.
    func recordGlobal(_ node: VariableDeclSyntax) {
        let isVar = node.bindingSpecifier.tokenKind == .keyword(.var)
        for binding in node.bindings {
            let isStored = MemberFacts.isStored(binding)
            for name in MemberFacts.names(in: binding.pattern) {
                declarations.globals.append(GlobalFact(
                    name: name,
                    isStoredVar: isVar && isStored,
                    file: context.file ?? "",
                    isFileScoped: SyntaxFacts.isFileScoped(node.modifiers)
                ))
            }
        }
    }

    /// Records a top-level typealias.
    func recordTypealias(_ node: TypeAliasDeclSyntax) {
        let alias = MemberFacts.typealiasFact(node, typePath: [], file: context.file ?? "", localTo: nil)
        declarations.typealiases.append(alias)
    }

    /// Records an import.
    func recordImport(_ node: ImportDeclSyntax) {
        guard let module = node.path.first.map({ SyntaxFacts.name($0.name) }) else {
            return
        }
        let isExported = SyntaxFacts.attributes(node.attributes).contains { attribute in
            attribute.attributeName.trimmedDescription == "_exported"
        }
        imports.append(ImportFact(
            module: module,
            isExported: isExported,
            condition: conditions.isEmpty ? nil : SyntaxFacts.conjunction(conditions),
            file: context.file ?? ""
        ))
    }

    /// The lexical type position of the current scopes: the type path since
    /// the last record, how much of it an extension contributed, whether any
    /// of it is file-scoped, and the record that owns it when it is local.
    func lexicalPosition() -> LexicalPosition {
        var position = LexicalPosition()
        // A record keeps the enclosing types for itself and its nested
        // functions; a type declared inside it starts a new path, local to it.
        var pendingOwner: MemberKey?
        for scope in scopes {
            switch scope {
            case .record(let record):
                // A key context (an unscored initial value) owns its local types
                // too, under a key of its own, so they never merge with module types.
                let owner = record.draftIndex.map { drafts[$0].key }
                    ?? MemberKey(module: context.module, text: "<context> " + record.fullKey)
                pendingOwner = owner
                position.enclosingRecords.append(owner)
                position.genericParameters += record.genericParameters

            case .type(let type):
                if let owner = pendingOwner {
                    position.enclosingTypePath = position.typePath
                    position.enclosingLocalOwner = position.localOwner
                    position.typePath = []
                    position.extensionPathLength = 0
                    position.isFileScoped = false
                    position.localOwner = owner
                    pendingOwner = nil
                }
                if position.typePath.isEmpty, type.isExtension {
                    position.extensionPathLength = type.nominal.count
                }
                position.typePath += type.nominal
                position.isFileScoped = position.isFileScoped || type.isFileScoped
                position.genericParameters += type.genericParameters
            }
        }
        position.pendingOwner = pendingOwner
        if position.typePath.isEmpty {
            position.localOwner = nil
        }
        return position
    }

    /// The file pass's raw references for a record.
    func rawReferences(head: CouplingHead, body: [Syntax]) -> RawFunctionReferences {
        let position = lexicalPosition()
        let bodyCollector = ReferenceCollector(edgeKind: .body)
        for node in body {
            bodyCollector.walk(node)
        }
        let signatureCollector = ReferenceCollector(edgeKind: .signature)
        for node in head.signature {
            signatureCollector.walk(node)
        }
        let parameters = head.parameters?.map { parameter in
            RawParameter(
                hasDefault: parameter.defaultValue != nil,
                isVariadic: parameter.ellipsis != nil,
                isInout: TypeSpelling.isInout(parameter.type),
                shape: TypeSpelling.closureShape(parameter.type)
            )
        }
        return RawFunctionReferences(
            context: FunctionContext(
                typePath: position.typePath,
                extensionPathLength: position.extensionPathLength,
                localOwner: position.localOwner,
                enclosingRecords: position.enclosingRecords,
                genericParameters: position.genericParameters + head.genericParameters,
                isTypeLevel: head.isTypeLevel,
                file: context.file ?? ""
            ),
            calls: bodyCollector.calls,
            names: bodyCollector.names,
            memberReads: bodyCollector.memberReads,
            typeNames: signatureCollector.typeNames + bodyCollector.typeNames,
            macroExpansionCount: bodyCollector.macroExpansionCount,
            carriesParameters: parameters != nil,
            parameters: parameters ?? [],
            cohesion: bodyCollector.cohesion
        )
    }
}
