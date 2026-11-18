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

    /// A `super.name`: a compound `super.f(y:)` by its base name, and an
    /// undeclared `super.$a` or `super._a` as `a` (rule 4).
    private static func superMemberName(_ written: String, inherited: Set<String>) -> String {
        if let compound = compound(written) {
            return compound.name
        }
        if inherited.contains(written) == false, let stripped = wrapperBase(written), inherited.contains(stripped) {
            return stripped
        }
        return written
    }

    /// Where a use declared on the type itself really lands: an inherited
    /// property, when the type declares only methods by that name. A call
    /// passes its base name and labels.
    private static func refine(
        _ place: MemberPlace,
        _ name: String,
        call: MemberCall?,
        sets: MemberSets
    ) -> MemberPlace {
        let reachesInherited = call.map(sets.reachesInheritedProperty(callOf:)) ?? sets.reachesInheritedProperty(name)
        return place == .own && reachesInherited ? .inherited : place
    }

    /// The names whose nearest declaration, superclass by superclass from
    /// the nearest, is a stored instance property.
    private static func nearestStorage(_ chain: [[MemberFact]]) -> Set<String> {
        var seen: Set<String> = []
        var stored: Set<String> = []
        for members in chain {
            let properties = members.filter { $0.isTypeLevel == false && $0.kind.isProperty }
            for member in properties where seen.contains(member.name) == false {
                if member.kind == .storedProperty {
                    stored.insert(member.name)
                }
            }
            seen.formUnion(properties.map(\.name))
        }
        return stored
    }

    /// Files an inherited use: a touch candidate when it reads inherited
    /// storage, otherwise a reference (a method, a computed override).
    private static func fileInherited(
        _ name: String,
        call: MemberCall?,
        sets: MemberSets,
        into references: inout SelfReferences
    ) {
        if sets.readsInheritedStorage(name, call: call) {
            references.inherited.insert(name)
        } else {
            references.inheritedReferences.insert(name)
        }
    }

    /// The function's resolved uses of its own type's members.
    func selfReferences() -> SelfReferences {
        var references = SelfReferences()
        guard let owner = currentType, let entry = table.entries[owner] else {
            return references
        }
        let sets = memberSets(of: owner, entry: entry)
        for name in raw.names + raw.cohesion.shorthandBindings {
            classifyBare(name, sets: sets, into: &references)
        }
        for written in raw.cohesion.selfMembers {
            classifySelfMember(written, sets: sets, into: &references)
        }
        for written in raw.cohesion.superMembers {
            let name = Self.superMemberName(written, inherited: sets.inherited)
            Self.fileInherited(name, call: Self.compound(written), sets: sets, into: &references)
        }
        for call in raw.calls {
            classifyCall(call, sets: sets, into: &references)
            // Calling a stored closure property reads it (rules 1 and 2), unless
            // an instance method with those labels, own or inherited, is the callee.
            let memberCall = MemberCall(name: call.name, labels: call.labels)
            if sets.stored.contains(call.name), references.calls.contains(memberCall),
               sets.methods.contains(memberCall) == false {
                if sets.inheritedMethods.contains(memberCall) {
                    references.inheritedReferences.insert(call.name)
                } else {
                    references.memberNames.insert(call.name)
                }
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

    /// The member names of `owner` and its in-module superclasses.
    private func memberSets(of owner: TypeKey, entry: TypeEntry) -> MemberSets {
        let chain = table.superclasses(of: owner).map { table.entries[$0]?.members ?? [] }
        let inheritedMembers = chain.flatMap(\.self)
        let isProperty: (MemberFact) -> Bool = { member in
            member.isTypeLevel == false && (member.kind == .storedProperty || member.kind == .computedProperty)
        }
        let isMethod: (MemberFact) -> Bool = { $0.kind == .function && $0.isTypeLevel == false }
        let call: (MemberFact) -> MemberCall = { MemberCall(name: $0.name, labels: $0.labels.map(SyntaxFacts.bare)) }
        return MemberSets(
            own: Set(entry.members.map(\.name)),
            inherited: Set(inheritedMembers.map(\.name)),
            ownProperties: Set(entry.members.filter(isProperty).map(\.name)),
            inheritedProperties: Set(inheritedMembers.filter(isProperty).map(\.name)),
            stored: Set(entry.members.filter { $0.kind == .storedProperty && $0.isTypeLevel == false }.map(\.name)),
            // Only instance methods are reachable from an instance call.
            methods: Set(entry.members.filter(isMethod).map(call)),
            inheritedMethods: Set(inheritedMembers.filter(isMethod).map(call)),
            inheritedStorage: Self.nearestStorage(chain)
        )
    }

    /// A `self.name` that is not called: a compound `self.f(y:)` references
    /// the one overload its labels name; `self.$a` and `self._a` are checked
    /// again as `a` (rule 4).
    private func classifySelfMember(_ written: String, sets: MemberSets, into references: inout SelfReferences) {
        if let compound = Self.compound(written) {
            fileCompound(compound, place: sets.place(compound.name), sets: sets, into: &references)
            return
        }
        let place = Self.refine(sets.place(written), written, call: nil, sets: sets)
        if place == .undeclared, let stripped = Self.wrapperBase(written), sets.place(stripped) != .undeclared {
            let strippedPlace = Self.refine(sets.place(stripped), stripped, call: nil, sets: sets)
            file(stripped, at: strippedPlace, call: nil, sets: sets, into: &references)
        } else {
            file(written, at: place, call: nil, sets: sets, into: &references)
        }
    }

    /// A compound `f(y:)` references the one overload its labels name: an
    /// own one, else an inherited one, else every own `f` (rule 5).
    private func fileCompound(
        _ compound: MemberCall,
        place: MemberPlace,
        sets: MemberSets,
        into references: inout SelfReferences
    ) {
        let isInheritedOnly = sets.methods.contains(compound) == false && sets.inheritedMethods.contains(compound)
        if place == .own, isInheritedOnly == false {
            references.calls.insert(compound)
        } else {
            file(compound.name, at: place == .own ? .inherited : place, call: compound, sets: sets, into: &references)
        }
    }

    /// Files a `self.name` read or call by where it is declared.
    private func file(
        _ name: String,
        at place: MemberPlace,
        call: MemberCall?,
        sets: MemberSets,
        into references: inout SelfReferences
    ) {
        switch place {
        case .own:
            references.memberNames.insert(name)

        case .inherited:
            Self.fileInherited(name, call: call, sets: sets, into: &references)

        case .undeclared:
            references.unresolved.insert(name)
        }
    }

    /// A bare name: own, inherited or unresolved; wrapper names (`$a`,
    /// `_a`) that reach member lookup are tried again without the prefix.
    private func classifyBare(_ name: RawName, sets: MemberSets, into references: inout SelfReferences) {
        var resolution = resolveValue(name.name, lookup: name.lookup)
        if isTypeOrModuleName(name, resolution) {
            return
        }
        if case .ownMember = resolution, name.isCompound == false,
           sets.reachesInheritedProperty(name.name) {
            resolution = .inheritedMember
        }
        // `f(y:)` written bare references the one overload its labels name.
        if name.isCompound, resolution.isMember {
            var place = MemberPlace.inherited
            if case .ownMember = resolution {
                place = .own
            }
            fileCompound(MemberCall(name: name.name, labels: name.labels), place: place, sets: sets, into: &references)
            return
        }
        guard let stripped = Self.wrapperBase(name.name) else {
            record(name.name, resolution, lookup: name.lookup, sets: sets, into: &references)
            return
        }
        switch resolution {
        case .enumCase, .freeFunction, .global, .inheritedMember, .ownMember, .staticMember:
            // `_name` declared as is (a member, a global, a free function): not a wrapper name.
            record(name.name, resolution, lookup: name.lookup, sets: sets, into: &references)

        case .notCoupling where name.name.hasPrefix("$") == false:
            // A local or file-level `_a` that lexical lookup finds is declared.
            record(name.name, resolution, lookup: name.lookup, sets: sets, into: &references)

        case .notCoupling, .unresolved:
            // An undeclared `_a`, or any `$a`, is retried as `a`.
            if Self.reachesMembers(name.lookup) {
                var retried = resolveValue(stripped, lookup: name.lookup)
                if case .ownMember = retried, sets.reachesInheritedProperty(stripped) {
                    retried = .inheritedMember
                }
                record(stripped, retried, lookup: name.lookup, sets: sets, into: &references)
            }
        }
    }

    /// An uppercase name, or a module name (`os.Logger`), in type position
    /// that resolves to no member: a type or module, not a use. An
    /// uppercase member is a use: `ID.lowercased()`.
    private func isTypeOrModuleName(_ name: RawName, _ resolution: ValueResolution) -> Bool {
        guard name.isTypePosition, resolution.isMember == false else {
            return false
        }
        return CalleeReader.startsUppercase(name.name) || context.knownModules.contains(name.name)
    }

    /// Files a bare name by its §7.2 resolution.
    private func record(
        _ name: String,
        _ resolution: ValueResolution,
        lookup: [StoredLookupResult],
        sets: MemberSets,
        into references: inout SelfReferences
    ) {
        switch resolution {
        case .ownMember:
            references.memberNames.insert(name)

        case .inheritedMember:
            Self.fileInherited(name, call: nil, sets: sets, into: &references)

        case .unresolved:
            if Self.reachesMembers(lookup), isPlatformFreeFunction(name) == false {
                references.unresolved.insert(name)
            }

        case .enumCase, .freeFunction, .global, .notCoupling, .staticMember:
            break
        }
    }

    /// A call of an own, inherited or undeclared member.
    private func classifyCall(_ call: RawCall, sets: MemberSets, into references: inout SelfReferences) {
        switch call.shape {
        case .selfMember:
            let memberCall = MemberCall(name: call.name, labels: call.labels)
            let place = Self.refine(sets.place(call.name), call.name, call: memberCall, sets: sets)
            if place == .own {
                references.calls.insert(MemberCall(name: call.name, labels: call.labels))
            } else {
                file(call.name, at: place, call: memberCall, sets: sets, into: &references)
            }

        case .superMember:
            let memberCall = MemberCall(name: call.name, labels: call.labels)
            Self.fileInherited(call.name, call: memberCall, sets: sets, into: &references)

        case .bare(let lookup):
            classifyBareCall(call, lookup: lookup, sets: sets, into: &references)

        case .chain, .implicitMember, .other, .qualified, .selfType:
            break
        }
    }

    /// An unqualified call: an own or inherited member, or one that reaches
    /// member lookup and finds nothing, unless it is a known free function.
    private func classifyBareCall(
        _ call: RawCall,
        lookup: [StoredLookupResult],
        sets: MemberSets,
        into references: inout SelfReferences
    ) {
        let memberCall = MemberCall(name: call.name, labels: call.labels)
        switch resolveValue(call.name, lookup: lookup) {
        case .ownMember where sets.reachesInheritedProperty(callOf: memberCall):
            Self.fileInherited(call.name, call: memberCall, sets: sets, into: &references)

        case .ownMember:
            references.calls.insert(memberCall)

        case .inheritedMember:
            Self.fileInherited(call.name, call: memberCall, sets: sets, into: &references)

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
