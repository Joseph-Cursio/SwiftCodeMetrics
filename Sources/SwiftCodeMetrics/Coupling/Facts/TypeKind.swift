//
//  TypeKind.swift
//  SwiftCodeMetrics
//
//  The nominal type kinds (Spec §2.2).
//

/// The kind of a type declaration.
enum TypeKind: String, Codable {
    /// `class`.
    case `class`
    /// `enum`.
    case `enum`
    /// `protocol`.
    case `protocol`
    /// `struct`.
    case `struct`
    /// `actor`.
    case actor
    /// Extensions of a type the module does not declare (Spec §2.2): members, no storage.
    case extensionGroup = "extension_group"
}
