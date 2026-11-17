//
//  ClosureShape.swift
//  SwiftCodeMetrics
//
//  Whether a parameter type is a closure, once attributes, optionality and
//  parentheses are stripped; a named type may be a module typealias.
//

/// A parameter type's closure-ness.
enum ClosureShape: Codable, Hashable {
    /// A function type; escaping if `@escaping` or optional.
    case function(escaping: Bool)
    /// A named type, which the module pass expands if it is a typealias;
    /// escaping if `@escaping` or optional.
    case named(SpelledType, escaping: Bool)
    /// Anything else.
    case other
}
