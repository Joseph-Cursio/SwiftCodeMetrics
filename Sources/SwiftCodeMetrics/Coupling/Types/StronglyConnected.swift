//
//  StronglyConnected.swift
//  SwiftCodeMetrics
//
//  Strongly connected components of the type graph (Spec §10.3), by Tarjan's algorithm.
//

/// Tarjan's strongly connected components.
struct StronglyConnected {
    /// Successors per node.
    private let successors: [TypeKey: [TypeKey]]
    /// Visit order per node.
    private var index: [TypeKey: Int] = [:]
    /// Lowest reachable visit order per node.
    private var lowLink: [TypeKey: Int] = [:]
    /// The stack.
    private var stack: [TypeKey] = []
    /// Nodes on the stack.
    private var onStack: Set<TypeKey> = []
    /// Components found.
    private var components: [[TypeKey]] = []
    /// The next visit order.
    private var counter = 0

    /// A search over `edges`.
    init(edges: [TypeCoupling]) {
        var next: [TypeKey: [TypeKey]] = [:]
        for edge in edges {
            next[edge.source, default: []].append(edge.target)
        }
        successors = next
    }

    /// Components of two or more types, each sorted, sorted by first type.
    static func cycles(in edges: [TypeCoupling]) -> [[TypeKey]] {
        var search = Self(edges: edges)
        let nodes = Set(edges.flatMap { [$0.source, $0.target] }).sorted { $0.description < $1.description }
        for node in nodes where search.index[node] == nil {
            search.visit(node)
        }
        return search.components
            .filter { $0.count > 1 }
            .map { $0.sorted { $0.description < $1.description } }
            .sorted { ($0.first?.description ?? "") < ($1.first?.description ?? "") }
    }

    /// One depth-first visit.
    private mutating func visit(_ node: TypeKey) {
        index[node] = counter
        lowLink[node] = counter
        counter += 1
        stack.append(node)
        onStack.insert(node)
        for next in successors[node] ?? [] {
            if index[next] == nil {
                visit(next)
                lowLink[node] = min(lowLink[node] ?? 0, lowLink[next] ?? 0)
            } else if onStack.contains(next) {
                lowLink[node] = min(lowLink[node] ?? 0, index[next] ?? 0)
            }
        }
        guard lowLink[node] == index[node] else {
            return
        }
        var component: [TypeKey] = []
        while let top = stack.popLast() {
            onStack.remove(top)
            component.append(top)
            if top == node {
                break
            }
        }
        components.append(component)
    }
}
