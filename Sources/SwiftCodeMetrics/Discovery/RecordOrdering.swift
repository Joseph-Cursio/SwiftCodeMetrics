//
//  RecordOrdering.swift
//  SwiftCodeMetrics
//
//  Puts drafts in record order (Spec §13.1): pre-order depth-first over the
//  parent tree, siblings by start offset, and assigns ids.
//

/// Orders drafts and turns them into records.
enum RecordOrdering {
    /// The records of `drafts`, in record order.
    static func records(from drafts: [FunctionDraft]) -> [FunctionRecord] {
        ordered(drafts).records
    }

    /// The records of `drafts` in record order, with their raw references.
    static func ordered(_ drafts: [FunctionDraft]) -> (records: [FunctionRecord], raw: [RawFunctionReferences?]) {
        var children: [Int?: [Int]] = [:]
        for (index, draft) in drafts.enumerated() {
            children[draft.parentDraft, default: []].append(index)
        }
        var order: [Int] = []
        var pending = sorted(children[nil] ?? [], in: drafts).reversed().map(\.self)
        while let next = pending.popLast() {
            order.append(next)
            pending += sorted(children[next] ?? [], in: drafts).reversed()
        }
        var ids: [Int: Int] = [:]
        for (id, index) in order.enumerated() {
            ids[index] = id
        }
        let records = order.enumerated().map { id, index in
            let draft = drafts[index]
            return FunctionRecord(
                id: id,
                parentID: draft.parentDraft.flatMap { ids[$0] },
                key: draft.key,
                parentKey: draft.parentDraft.map { drafts[$0].key },
                kind: draft.kind,
                name: draft.name,
                range: draft.range,
                lines: draft.lines,
                complexity: draft.complexity,
                couplingStatus: draft.kind == .propertyInitializer ? .notApplicableKind : .needsModulePass,
                parameters: nil,
                fanOut: nil,
                commonCoupling: nil,
                typeReferences: draft.raw?.typeNames
                    .filter { $0.isCandidate == false }
                    .map(\.unresolvedReference) ?? []
            )
        }
        return (records, order.map { drafts[$0].raw })
    }

    /// Sibling indices by start offset, then visit order.
    private static func sorted(_ indices: [Int], in drafts: [FunctionDraft]) -> [Int] {
        indices.sorted { (drafts[$0].range.start, $0) < (drafts[$1].range.start, $1) }
    }
}
