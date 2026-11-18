//
//  UnionFind.swift
//  SwiftCodeMetrics
//
//  Disjoint sets over node indices, for connected components.
//

/// A union-find over `0..<count`.
struct UnionFind {
    /// Each node's parent.
    private var parents: [Int]

    /// Every node in its own set.
    init(count: Int) {
        parents = Array(0..<count)
    }

    /// The set representative of `node`.
    mutating func find(_ node: Int) -> Int {
        var root = node
        while parents[root] != root {
            root = parents[root]
        }
        var current = node
        while parents[current] != root {
            let next = parents[current]
            parents[current] = root
            current = next
        }
        return root
    }

    /// Joins the sets of `first` and `second`.
    mutating func union(_ first: Int, _ second: Int) {
        let rootFirst = find(first)
        let rootSecond = find(second)
        if rootFirst != rootSecond {
            parents[max(rootFirst, rootSecond)] = min(rootFirst, rootSecond)
        }
    }

    /// The sets, each in node order, ordered by their first node.
    mutating func groups() -> [[Int]] {
        var byRoot: [Int: [Int]] = [:]
        var order: [Int] = []
        for node in parents.indices {
            let root = find(node)
            if byRoot[root] == nil {
                order.append(root)
            }
            byRoot[root, default: []].append(node)
        }
        return order.compactMap { byRoot[$0] }
    }
}
