//
//  FunctionResolver+Cohesion.swift
//  SwiftCodeMetrics
//
//  Resolves one function's uses of its own type's members for the cohesion
//  graph (Spec §9.3 accesses and member edges).
//

extension FunctionResolver {
    /// The function's own type, if any.
    var currentType: TypeKey? {
        context.chain.first
    }

    /// Where a `self.name` or `self.name(...)` is declared.
    private static func place(_ name: String, own: Set<String>, inherited: Set<String>) -> MemberPlace {
        if own.contains(name) {
            return .own
        }
        return inherited.contains(name) ? .inherited : .undeclared
    }

    /// `x` for `$x` or `_x`.
    private static func wrapperBase(_ name: String) -> String? {
        guard name.count > 1, let first = name.first, first == "$" || first == "_" else {
            return nil
        }
        return String(name.dropFirst())
    }

    /// Whether lookup reaches member lookup before any local.
    private static func reachesMembers(_ lookup: [StoredLookupResult]) -> Bool {
        for result in lookup {
            switch result {
            case .local:
                return false

            case .members:
                return true

            case .genericParameters, .implicitClosureParameters:
                continue
            }
        }
        return false
    }

    /// `f(y:)` as a base name and labels; nil for a plain name.
    private static func compound(_ written: String) -> MemberCall? {
        guard let open = written.firstIndex(of: "("), written.hasSuffix(")") else {
            return nil
        }
        let inside = written[written.index(after: open)..<written.index(before: written.endIndex)]
        return MemberCall(name: String(written[..<open]), labels: inside.split(separator: ":").map(String.init))
    }

    /// Whether a key path root names the type: `Self`, or a suffix of its path.
    private static func isOwnRoot(_ root: [String], of owner: TypeKey) -> Bool {
        root == ["Self"] || (root.count <= owner.path.count && Array(owner.path.suffix(root.count)) == root)
    }

    /// The function's resolved uses of its own type's members.
    func selfReferences() -> SelfReferences {
        var references = SelfReferences()
        guard let owner = currentType, let entry = table.entries[owner] else {
            return references
        }
        let own = Set(entry.members.map(\.name))
        let stored = Set(entry.members.filter { $0.kind == .storedProperty && $0.isTypeLevel == false }.map(\.name))
        let methods = Set(entry.members.filter { $0.kind == .function }.map { member in
            MemberCall(name: member.name, labels: member.labels.map(SyntaxFacts.bare))
        })
        let inherited = Set(table.superclasses(of: owner).flatMap { table.entries[$0]?.members ?? [] }.map(\.name))
        for name in raw.names + raw.cohesion.shorthandBindings {
            classifyBare(name, into: &references)
        }
        for written in raw.cohesion.selfMembers {
            classifySelfMember(written, own: own, inherited: inherited, into: &references)
        }
        references.inherited.formUnion(raw.cohesion.superMembers)
        for call in raw.calls {
            classifyCall(call, own: own, inherited: inherited, into: &references)
            // Calling a stored closure property reads it (rules 1 and 2), unless
            // a method with those labels is the callee.
            let memberCall = MemberCall(name: call.name, labels: call.labels)
            if stored.contains(call.name), references.calls.contains(memberCall),
               methods.contains(memberCall) == false {
                references.memberNames.insert(call.name)
            }
        }
        for keyPath in raw.cohesion.keyPaths {
            if keyPath.root.isEmpty {
                references.rootlessKeyPaths.insert(keyPath.firstComponent)
            } else if Self.isOwnRoot(keyPath.root, of: owner) {
                references.keyPathMembers.insert(keyPath.firstComponent)
            }
        }
        references.wholeSelf = raw.cohesion.wholeSelfUses > 0
        references.selfSubscript = raw.cohesion.selfSubscriptUses > 0
        return references
    }

    /// A `self.name` that is not called: a compound `self.f(y:)` references
    /// the one overload its labels name; `self.$a` and `self._a` are checked
    /// again as `a` (rule 4).
    private func classifySelfMember(
        _ written: String,
        own: Set<String>,
        inherited: Set<String>,
        into references: inout SelfReferences
    ) {
        if let compound = Self.compound(written) {
            let place = Self.place(compound.name, own: own, inherited: inherited)
            if place == .own {
                references.calls.insert(compound)
            } else {
                file(compound.name, at: place, into: &references)
            }
            return
        }
        let place = Self.place(written, own: own, inherited: inherited)
        if place == .undeclared, let stripped = Self.wrapperBase(written),
           Self.place(stripped, own: own, inherited: inherited) != .undeclared {
            file(stripped, at: Self.place(stripped, own: own, inherited: inherited), into: &references)
        } else {
            file(written, at: place, into: &references)
        }
    }

    /// Files a `self.name` read by where it is declared.
    private func file(_ name: String, at place: MemberPlace, into references: inout SelfReferences) {
        switch place {
        case .own:
            references.memberNames.insert(name)

        case .inherited:
            references.inherited.insert(name)

        case .undeclared:
            references.unresolved.insert(name)
        }
    }

    /// A bare name: own, inherited or unresolved; wrapper names (`$a`,
    /// `_a`) that reach member lookup are tried again without the prefix.
    private func classifyBare(_ name: RawName, into references: inout SelfReferences) {
        if CalleeReader.startsUppercase(name.name), name.isTypePosition {
            return
        }
        let resolution = resolveValue(name.name, lookup: name.lookup)
        // `f(y:)` written bare references the one overload its labels name.
        if name.isCompound, case .ownMember = resolution {
            references.calls.insert(MemberCall(name: name.name, labels: name.labels))
            return
        }
        guard let stripped = Self.wrapperBase(name.name) else {
            record(name.name, resolution, lookup: name.lookup, into: &references)
            return
        }
        switch resolution {
        case .inheritedMember, .ownMember:
            // `_name` declared as is, own or inherited: not a wrapper name.
            record(name.name, resolution, lookup: name.lookup, into: &references)

        case .enumCase, .freeFunction, .global, .notCoupling, .staticMember, .unresolved:
            if Self.reachesMembers(name.lookup) {
                record(stripped, resolveValue(stripped, lookup: name.lookup), lookup: name.lookup, into: &references)
            }
        }
    }

    /// Files a bare name by its §7.2 resolution.
    private func record(
        _ name: String,
        _ resolution: ValueResolution,
        lookup: [StoredLookupResult],
        into references: inout SelfReferences
    ) {
        switch resolution {
        case .ownMember:
            references.memberNames.insert(name)

        case .inheritedMember:
            references.inherited.insert(name)

        case .unresolved:
            if Self.reachesMembers(lookup), isPlatformFreeFunction(name) == false {
                references.unresolved.insert(name)
            }

        case .enumCase, .freeFunction, .global, .notCoupling, .staticMember:
            break
        }
    }

    /// A call of an own, inherited or undeclared member.
    private func classifyCall(
        _ call: RawCall,
        own: Set<String>,
        inherited: Set<String>,
        into references: inout SelfReferences
    ) {
        switch call.shape {
        case .selfMember:
            let place = Self.place(call.name, own: own, inherited: inherited)
            if place == .own {
                references.calls.insert(MemberCall(name: call.name, labels: call.labels))
            } else {
                file(call.name, at: place, into: &references)
            }

        case .superMember:
            references.inherited.insert(call.name)

        case .bare(let lookup):
            classifyBareCall(call, lookup: lookup, into: &references)

        case .chain, .implicitMember, .other, .qualified, .selfType:
            break
        }
    }

    /// An unqualified call: an own or inherited member, or one that reaches
    /// member lookup and finds nothing, unless it is a known free function.
    private func classifyBareCall(
        _ call: RawCall,
        lookup: [StoredLookupResult],
        into references: inout SelfReferences
    ) {
        switch resolveValue(call.name, lookup: lookup) {
        case .ownMember:
            references.calls.insert(MemberCall(name: call.name, labels: call.labels))

        case .inheritedMember:
            references.inherited.insert(call.name)

        case .unresolved:
            let isKnownFunction = table.isFreeFunction(call.name, from: context.file)
                || isPlatformFreeFunction(call.name)
                || options.diagnosticFreeFunctions.contains(call.name)
            if Self.reachesMembers(lookup), isKnownFunction == false, CalleeReader.startsUppercase(call.name) == false {
                references.unresolved.insert(call.name)
            }

        case .enumCase, .freeFunction, .global, .notCoupling, .staticMember:
            break
        }
    }
}
