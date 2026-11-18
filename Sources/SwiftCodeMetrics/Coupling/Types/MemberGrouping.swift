//
//  MemberGrouping.swift
//  SwiftCodeMetrics
//
//  Groups a type's records into members (Spec §2.3, §2.6): accessors of
//  one property or subscript form one member, `#if` variants merge, and
//  nested functions belong to the member around them.
//

/// Builds member groups from records.
enum MemberGrouping {
    /// The members of every type, from the records each type owns.
    static func groups(functions: [FunctionRecord], facts: [RecordFacts?]) -> [TypeKey: [MemberGroup]] {
        var byType: [TypeKey: [String: MemberGroup]] = [:]
        for (index, fact) in facts.enumerated() {
            guard let fact else {
                continue
            }
            let root = root(of: index, functions: functions, facts: facts)
            let record = functions[root]
            let parts = split(record.key.text)
            // A private member's key carries its file: two files, two members.
            let identity = parts.identity + "\u{1}" + (record.key.file ?? "")
            if root == index {
                if byType[fact.owner]?[identity] == nil {
                    byType[fact.owner, default: [:]][identity] = group(for: record, identity: parts.identity)
                }
                byType[fact.owner]?[identity]?.variants[parts.condition, default: []].append(index)
                if fact.isTypeLevel {
                    byType[fact.owner]?[identity]?.isTypeLevel = true
                }
            }
            byType[fact.owner]?[identity]?.records.append(index)
        }
        return byType.mapValues { groups in groups.values.sorted { $0.firstRecord < $1.firstRecord } }
    }

    /// An empty group for a root record.
    private static func group(for record: FunctionRecord, identity: String) -> MemberGroup {
        let role = role(of: record)
        let (baseName, labels) = nameParts(record.name, role: role)
        // A function inside a stored property's initial value sits under a
        // key context whose last component names no type: not a member.
        let last = identity.components(separatedBy: " / ").last ?? identity
        // `Local::func go()` starts with a type path; `func pad(_: Lib::Int)` does not.
        let typePath = last.components(separatedBy: "::").first ?? ""
        let startsWithTypePath = last.contains("::")
            && typePath.contains(" ") == false && typePath.contains("(") == false
        return MemberGroup(
            key: MemberKey(module: record.key.module, text: identity, file: record.key.file),
            role: role,
            isTypeLevel: false,
            isMember: identity.contains(" / ") == false || startsWithTypePath,
            baseName: baseName,
            labels: labels,
            variants: [:],
            records: []
        )
    }

    /// The outermost record above `index` with the same owner.
    static func root(of index: Int, functions: [FunctionRecord], facts: [RecordFacts?]) -> Int {
        var current = index
        while let parent = functions[current].parentID, let owner = facts[parent]?.owner, owner == facts[index]?.owner {
            current = parent
        }
        return current
    }

    /// A key's text without `#if` conditions, numbering or accessor, and the conditions.
    static func split(_ text: String) -> (identity: String, condition: String) {
        var components = text.components(separatedBy: " / ")
        var conditions: [String] = []
        components = components.map { component in
            var trimmed = component
            if let numbered = trimmed.range(of: #" #\d+$"#, options: .regularExpression) {
                trimmed.removeSubrange(numbered)
            }
            // A context's key keeps its file (`… #if DEBUG @ Grid.swift`): part of the identity.
            var file = ""
            if let suffix = trimmed.range(of: " @ ", options: .backwards) {
                file = String(trimmed[suffix.lowerBound...])
                trimmed = String(trimmed[..<suffix.lowerBound])
            }
            if let condition = trimmed.range(of: " #if ") {
                conditions.append(String(trimmed[condition.upperBound...]))
                trimmed = String(trimmed[..<condition.lowerBound])
            }
            return trimmed + file
        }
        if let last = components.last, last.hasPrefix("{ "), last.hasSuffix(" }"), components.count > 1 {
            components.removeLast()
        } else if let last = components.last,
                  let accessor = last.range(of: #" \{ [A-Za-z_]+ \}$"#, options: .regularExpression) {
            components[components.count - 1] = String(last[..<accessor.lowerBound])
        }
        return (components.joined(separator: " / "), conditions.joined(separator: " && "))
    }

    /// The member kind a root record stands for.
    private static func role(of record: FunctionRecord) -> MemberRole {
        switch record.kind {
        case .accessor:
            if record.name.hasPrefix("subscript(") {
                return .subscriptMember
            }
            return record.name.hasSuffix(".willSet") || record.name.hasSuffix(".didSet") ? .observer : .computedProperty

        case .computedGetter:
            return .computedProperty

        case .deinitializer:
            return .deinitializer

        case .function, .propertyInitializer, .topLevelCode:
            return .function

        case .initializer:
            return .initializer

        case .subscriptGetter:
            return .subscriptMember
        }
    }

    /// The base name and labels in a readable name: `load(userID:)`,
    /// `total.get`, `subscript(_:).get`.
    private static func nameParts(_ name: String, role: MemberRole) -> (String, [String]) {
        var text = name
        if role == .computedProperty || role == .observer || role == .subscriptMember,
           let dot = text.range(of: ".", options: .backwards), text[dot.upperBound...].contains("(") == false {
            text = String(text[..<dot.lowerBound])
        }
        guard let open = text.firstIndex(of: "("), text.hasSuffix(")") else {
            return (SyntaxFacts.bare(text), [])
        }
        let inside = text[text.index(after: open)..<text.index(before: text.endIndex)]
        let labels = inside.split(separator: ":").map { SyntaxFacts.bare(String($0)) }
        return (SyntaxFacts.bare(String(text[..<open])), labels)
    }
}
