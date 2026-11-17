//
//  TypeResolution.swift
//  SwiftCodeMetrics
//
//  What a type name resolved to (Spec §7.3).
//

/// The outcome of resolving a type name.
enum TypeResolution: Equatable {
    /// More than one module type matched.
    case ambiguous
    /// Not declared in the module or the platform table.
    case external(String)
    /// A generic parameter or associated type: not coupling.
    case genericParameter
    /// A module type.
    case module(TypeKey)
    /// A typealias whose target is not a named type, such as a function type.
    case opaqueAlias
    /// In the platform table.
    case platform(String)
    /// It names only module types it cannot reach (Spec §7.3 step 5).
    case unresolved

    /// Whether it names a module type.
    var isModuleType: Bool {
        if case .module = self {
            return true
        }
        return false
    }

    /// Whether it names a platform type.
    var isPlatformType: Bool {
        if case .platform = self {
            return true
        }
        return false
    }

    /// The module type, if it names one.
    var moduleKey: TypeKey? {
        if case .module(let key) = self {
            return key
        }
        return nil
    }
}
