//
//  OwnBodyVisitor.swift
//  SwiftCodeMetrics
//
//  A visitor that stays inside one function's own body (Spec §2.1):
//  closures fold in, but nested functions, local types, local accessors and
//  globals are records of their own and are skipped. Unexpected syntax is
//  skipped too (Spec §2.8).
//

import SwiftSyntax

/// The base class for walkers that score a function's own body.
class OwnBodyVisitor: SyntaxVisitor {
    /// Creates a source-accurate visitor.
    init() {
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_: UnexpectedNodesSyntax) -> SyntaxVisitorContinueKind {
        .skipChildren
    }

    override func visit(_: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        .skipChildren
    }

    override func visit(_: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        .skipChildren
    }

    override func visit(_: DeinitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        .skipChildren
    }

    override func visit(_: SubscriptDeclSyntax) -> SyntaxVisitorContinueKind {
        .skipChildren
    }

    override func visit(_: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        .skipChildren
    }

    override func visit(_: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        .skipChildren
    }

    override func visit(_: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        .skipChildren
    }

    override func visit(_: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        .skipChildren
    }

    override func visit(_: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        .skipChildren
    }

    override func visit(_: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        .skipChildren
    }

    /// A local computed or observed variable's accessors are their own
    /// records; its initial value stays in the body.
    override func visit(_ node: AccessorBlockSyntax) -> SyntaxVisitorContinueKind {
        node.parent?.is(PatternBindingSyntax.self) == true ? .skipChildren : .visitChildren
    }

    /// A global's initial value is not top-level code (Spec §2.1).
    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        SyntaxFacts.isGlobal(node) ? .skipChildren : .visitChildren
    }

    deinit {
        // Nothing to release beyond stored properties.
    }
}
