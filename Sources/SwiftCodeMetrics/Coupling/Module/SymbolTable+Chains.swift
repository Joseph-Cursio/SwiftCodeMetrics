//
//  SymbolTable+Chains.swift
//  SwiftCodeMetrics
//
//  The types around a type (Spec §7.3 step 3), and file visibility of
//  file-scoped types.
//

extension SymbolTable {
    /// The enclosing types of `key`, innermost first, the type itself included.
    func chain(from key: TypeKey) -> [TypeKey] {
        var visited: Set<TypeKey> = []
        return chain(from: key, visited: &visited)
    }

    /// The chain, with a guard against cycles through local owners.
    private func chain(from key: TypeKey, visited: inout Set<TypeKey>) -> [TypeKey] {
        guard visited.insert(key).inserted else {
            return []
        }
        var chain = [key]
        var path = key.path
        while path.count > 1 {
            path.removeLast()
            let localParent = key.localTo.flatMap { locals[$0]?[path] }
            let parent = localParent ?? visible(byPath[path] ?? [], from: key.file ?? "").first ?? extensionGroups[path]
            if let parent {
                chain.append(parent)
            }
        }
        // A local type also sees the types around the function that owns it.
        guard let owner = key.localTo, let first = key.path.first, let outermost = locals[owner]?[[first]],
              let entry = entries[outermost], entry.enclosingTypePath.isEmpty == false else {
            return chain
        }
        let enclosingPath = entry.enclosingLocalOwner == nil
            ? entry.enclosingTypePath
            : [NameLookup.localMarker] + entry.enclosingTypePath
        let localOwners = entry.enclosingLocalOwner.map { [$0] } ?? []
        if let enclosing = type(atPath: enclosingPath, from: entry.file, localOwners: localOwners) {
            chain += self.chain(from: enclosing, visited: &visited)
        }
        return chain
    }

    /// The keys visible from `file`: not file-scoped, or declared there.
    func visible(_ keys: [TypeKey], from file: String) -> [TypeKey] {
        keys.filter { $0.file == nil || $0.file == file }
    }
}
