//
//  SymbolTable+Compositions.swift
//  SwiftCodeMetrics
//
//  Typealias compositions, expanded (Spec §9.5): `typealias Services =
//  Persisting & Caching` where `Persisting = Loading & Saving` stands for
//  Loading, Saving and Caching, and an alias of an alias follows the chain.
//

extension SymbolTable {
    /// The named types a typealias composition stands for, each with the
    /// position it resolves from; empty when `type` reaches no composition.
    func compositionLeaves(of type: SpelledType, from context: ResolutionContext) -> [CompositionLeaf] {
        var visiting: Set<String> = []
        return leaves(of: type, from: context, visiting: &visiting)
    }

    /// The module class a superclass entry names, directly or as the first
    /// class in a typealias composition (`typealias ThemedBase = Base & Themed`).
    func moduleClass(_ type: SpelledType, from context: ResolutionContext) -> TypeKey? {
        if case .module(let key) = resolve(type, from: context) {
            return entries[key]?.kind == .class ? key : nil
        }
        return compositionLeaves(of: type, from: context).lazy.compactMap { leaf -> TypeKey? in
            guard case .module(let key) = self.resolve(leaf.type, from: leaf.position),
                  self.entries[key]?.kind == .class else {
                return nil
            }
            return key
        }.first
    }

    /// The leaves, with a guard against alias cycles.
    private func leaves(
        of type: SpelledType,
        from context: ResolutionContext,
        visiting: inout Set<String>
    ) -> [CompositionLeaf] {
        guard let alias = aliasTarget(for: type, from: context) else {
            return []
        }
        let identity = alias.file + "|" + alias.typePath.joined(separator: ".") + "|" + alias.name
        guard visiting.insert(identity).inserted else {
            return []
        }
        let position = position(of: alias, from: context)
        if alias.compositionMembers.isEmpty == false {
            return alias.compositionMembers.flatMap { member in
                let nested = leaves(of: member, from: position, visiting: &visiting)
                return nested.isEmpty ? [CompositionLeaf(type: member, position: position)] : nested
            }
        }
        return alias.target.map { leaves(of: $0, from: position, visiting: &visiting) } ?? []
    }
}
