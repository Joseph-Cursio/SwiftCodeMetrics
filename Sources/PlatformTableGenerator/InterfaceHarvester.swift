//
//  InterfaceHarvester.swift
//  PlatformTableGenerator
//
//  Collects the public and open type names, protocols and top-level
//  function names of one `.swiftinterface` (Spec §7.4, source 1).
//

import SwiftSyntax

/// Harvests declarations from a parsed interface.
final class InterfaceHarvester: SyntaxVisitor {
    /// Type names: top-level names and dotted paths of nested types.
    private(set) var types: Set<String> = []
    /// Protocol names.
    private(set) var protocols: Set<String> = []
    /// Top-level function names.
    private(set) var functions: Set<String> = []

    /// Enclosing type or extended-type names, outermost first.
    private var stack: [[String]] = []

    /// Creates a harvester.
    init() {
        super.init(viewMode: .sourceAccurate)
    }

    /// Whether the modifiers include `public` or `open`.
    private static func isPublic(_ modifiers: DeclModifierListSyntax) -> Bool {
        modifiers.contains { $0.name.tokenKind == .keyword(.public) || $0.name.tokenKind == .keyword(.open) }
    }

    /// The name components of an extended type, generic arguments dropped.
    private static func components(of type: TypeSyntax) -> [String] {
        if let member = type.as(MemberTypeSyntax.self) {
            return components(of: member.baseType) + [member.name.text]
        }
        if let identifier = type.as(IdentifierTypeSyntax.self) {
            return [identifier.name.text]
        }
        return [type.trimmedDescription]
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        open(node.name.text, node.modifiers, isProtocol: false)
    }

    override func visitPost(_: StructDeclSyntax) {
        stack.removeLast()
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        open(node.name.text, node.modifiers, isProtocol: false)
    }

    override func visitPost(_: ClassDeclSyntax) {
        stack.removeLast()
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        open(node.name.text, node.modifiers, isProtocol: false)
    }

    override func visitPost(_: EnumDeclSyntax) {
        stack.removeLast()
    }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        open(node.name.text, node.modifiers, isProtocol: false)
    }

    override func visitPost(_: ActorDeclSyntax) {
        stack.removeLast()
    }

    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        open(node.name.text, node.modifiers, isProtocol: true)
    }

    override func visitPost(_: ProtocolDeclSyntax) {
        stack.removeLast()
    }

    /// A top-level extension's extended type counts too: types imported
    /// from C or Objective-C, such as `DispatchQueue`, appear only this way.
    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        let components = Self.components(of: node.extendedType)
        if stack.isEmpty, components.allSatisfy({ $0.first?.isLetter == true || $0.first == "_" }) {
            types.insert(components.joined(separator: "."))
        }
        stack.append(components)
        return .visitChildren
    }

    override func visitPost(_: ExtensionDeclSyntax) {
        stack.removeLast()
    }

    override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
        if Self.isPublic(node.modifiers) {
            types.insert(path(node.name.text))
        }
        return .skipChildren
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        if stack.isEmpty, Self.isPublic(node.modifiers), case .identifier(let name) = node.name.tokenKind {
            functions.insert(name)
        }
        return .skipChildren
    }

    override func visit(_: CodeBlockSyntax) -> SyntaxVisitorContinueKind {
        .skipChildren
    }

    /// Records a type if it is public or open, and opens its scope.
    private func open(
        _ name: String,
        _ modifiers: DeclModifierListSyntax,
        isProtocol: Bool
    ) -> SyntaxVisitorContinueKind {
        if Self.isPublic(modifiers) {
            types.insert(path(name))
            if isProtocol, stack.isEmpty {
                protocols.insert(name)
            }
        }
        stack.append([name])
        return .visitChildren
    }

    /// `name` under the enclosing types, dotted.
    private func path(_ name: String) -> String {
        (stack.flatMap(\.self) + [name]).joined(separator: ".")
    }

    deinit {
        // Nothing to release beyond stored properties.
    }
}
