//
//  LabelMatcher.swift
//  SwiftCodeMetrics
//
//  Whether a call's argument labels fit a parameter list, by the syntax-only
//  reduction of Swift's matching rules in Spec §3.4 rule 4.
//

/// Matches call arguments to parameters left to right.
enum LabelMatcher {
    /// Whether `arguments` fit `parameters`. In strict mode no parameter may
    /// be left to its default, and a variadic must take at least one argument.
    static func fits(_ arguments: [CallArgument], _ parameters: [CallableParameter], strict: Bool) -> Bool {
        var cursor = 0
        var openVariadic = false
        for argument in arguments {
            let target: Int?
            switch argument {
            case .labeled("_") where openVariadic:
                continue

            case .labeled(let label):
                target = parameters.indices.first { $0 >= cursor && parameters[$0].label == label }

            case .trailingClosure:
                target = parameters.indices.first { $0 >= cursor && parameters[$0].isFunctionType }
            }
            guard let index = target, canSkip(parameters[cursor..<index], strict: strict) else {
                return false
            }
            cursor = index + 1
            openVariadic = parameters[index].isVariadic && argument != .trailingClosure
        }
        return canSkip(parameters[cursor...], strict: strict)
    }

    /// Whether every parameter in `skipped` may receive no argument.
    private static func canSkip(_ skipped: ArraySlice<CallableParameter>, strict: Bool) -> Bool {
        skipped.allSatisfy { strict == false && ($0.hasDefault || $0.isVariadic) }
    }
}
