//
//  FunctionResolver+Coupling.swift
//  SwiftCodeMetrics
//
//  Common coupling (Spec §8.2), parameter counts (Spec §8.3) and resolved
//  type references (Spec §7.3).
//

extension FunctionResolver {
    /// What a parameter's type says about closures.
    private enum ParameterClosure {
        /// A closure that escapes.
        case escaping
        /// Not a closure.
        case nonClosure
        /// A closure that does not escape.
        case nonEscaping
    }

    /// Globals, statics and singletons referenced.
    func commonCoupling() -> CommonCoupling {
        var tally = CouplingTally()
        for name in raw.names {
            countName(name, into: &tally)
        }
        for call in raw.calls {
            if case .qualified(let base, _) = call.shape, isThisModule(base),
               let global = table.global(call.name, from: context.file) {
                tally.addGlobal(global)
            }
            guard case .bare(let lookup) = call.shape else {
                continue
            }
            switch resolveValue(call.name, lookup: lookup) {
            case .global(let global):
                tally.addGlobal(global)

            case let .staticMember(owner, member)
                where member.kind.isProperty && hasStaticMethod(call.name, labels: call.labels, on: owner) == false:
                // `onSave()` calls a static closure property: a static reference.
                tally.addStatic(owner: owner, member: member, kind: table.entries[owner]?.kind)

            default:
                break
            }
        }
        for read in raw.memberReads {
            countMemberRead(read, into: &tally)
        }
        return tally.result
    }

    /// The parameter counts, for records that carry them.
    func parameterCounts() -> ParameterCounts? {
        guard raw.carriesParameters else {
            return nil
        }
        let parameters = raw.parameters
        var counts = ParameterCounts(
            parameterCount: parameters.count,
            defaultedParameterCount: parameters.filter(\.hasDefault).count,
            variadicParameterCount: parameters.filter(\.isVariadic).count,
            inoutParameterCount: parameters.filter(\.isInout).count,
            closureParameterCount: 0,
            escapingClosureParameterCount: 0
        )
        for parameter in parameters {
            switch closure(parameter.shape) {
            case .escaping:
                counts.closureParameterCount += 1
                counts.escapingClosureParameterCount += 1

            case .nonEscaping:
                counts.closureParameterCount += 1

            case .nonClosure:
                break
            }
        }
        return counts
    }

    /// The type references, resolved; generic parameters are dropped.
    func typeReferences() -> [TypeReference] {
        raw.typeNames.flatMap(expandedReferences(for:))
    }

    /// One type name's references: the name itself, or each type a typealias
    /// composition stands for (`let deps: Dependencies` where
    /// `Dependencies = HasAPI & HasStore`), as if the composition were written.
    func expandedReferences(for name: RawTypeName) -> [TypeReference] {
        if let reference = typeReference(for: name) {
            return [reference]
        }
        guard name.isCandidate == false, name.qualifierMustBeModule == false,
              case .opaqueAlias = table.resolve(name.type, from: context) else {
            return []
        }
        return table.compositionLeaves(of: name.type, from: context).compactMap { leaf in
            var member = name
            member.type = leaf.type
            return reference(member, resolution: table.resolve(leaf.type, from: leaf.position))
        }
    }

    /// One type name, resolved; nil for generic parameters and names that
    /// turn out not to be types.
    func typeReference(for name: RawTypeName) -> TypeReference? {
        let resolution: TypeResolution
        if name.qualifierMustBeModule, isModuleQualifier(name.type.moduleSelector) == false {
            return nil
        }
        if name.isCandidate, name.type.moduleSelector == nil {
            // `Self.State(...)`: only the nested type is a reference; `Self` itself is not.
            if name.type.components == ["Self"] {
                return nestedTarget(name).flatMap { reference($0.name, resolution: $0.resolution) }
            }
            guard case .type(let resolved) = classifyCandidate(name.type.spelling, lookup: name.lookup) else {
                return nil
            }
            // `A.B(...)` targets the nested type `A.B` when one is declared,
            // also under a platform type: `String.Limits` (Spec §7.3 step 4).
            if let nested = nestedTarget(name) {
                return reference(nested.name, resolution: nested.resolution)
            }
            resolution = resolved
        } else {
            resolution = table.resolve(name.type, from: context)
            // `Foundation.NSLog(...)`: a qualified free function, not a type.
            if name.isCandidate, resolution.isPlatformType == false, resolution.isModuleType == false,
               isPlatformFreeFunction(name.type.spelling)
                || table.isFreeFunction(name.type.spelling, from: context.file)
                || isThisModuleGlobal(name.type) {
                return nil
            }
            // `Lib.Form.State()` and `Lib::Form.State()`: the module stripped, then step 4.
            if name.isCandidate, resolution.isModuleType, let nested = nestedTarget(name) {
                return reference(nested.name, resolution: nested.resolution)
            }
        }
        return reference(name, resolution: resolution)
    }

    /// The longest `A.B…` an expression candidate continues with that names
    /// a module type, if any.
    private func nestedTarget(_ name: RawTypeName) -> (name: RawTypeName, resolution: TypeResolution)? {
        for length in stride(from: name.trailingMembers.count, to: 0, by: -1) {
            let components = name.type.components + name.trailingMembers.prefix(length)
            let spelled = SpelledType(components: components, moduleSelector: name.type.moduleSelector)
            let resolution = table.resolve(spelled, from: context)
            if resolution.isModuleType {
                var extended = name
                extended.type = spelled
                return (extended, resolution)
            }
        }
        return nil
    }

    /// A reference from a resolution.
    private func reference(_ name: RawTypeName, resolution: TypeResolution) -> TypeReference? {
        var reference = name.unresolvedReference
        switch resolution {
        case .module(let key):
            reference.bucket = .module
            reference.target = key
            reference.resolution = .exact

        case .platform(let name):
            reference.bucket = .platform
            reference.resolution = .exact
            reference.resolvedName = name

        case .external(let name):
            reference.bucket = .external
            reference.resolution = .approximate
            reference.resolvedName = name

        case .ambiguous:
            reference.resolution = .ambiguous

        case .unresolved:
            reference.resolution = .unresolved

        case .genericParameter, .opaqueAlias:
            return nil
        }
        return reference
    }

    /// Whether a parameter is a closure, and whether it escapes.
    private func closure(_ shape: ClosureShape) -> ParameterClosure {
        switch shape {
        case .function(let escaping):
            return escaping ? .escaping : .nonEscaping

        case let .named(spelled, escaping):
            // Expand module typealiases by the §7.3 order, one level at a
            // time from each alias's own position; optionality anywhere escapes.
            var visited: Set<String> = []
            var current = (spelled: spelled, escaping: escaping, context: context)
            while let alias = table.aliasTarget(for: current.spelled, from: current.context),
                  visited.insert(alias.file + "|" + alias.typePath.joined(separator: ".") + "|" + alias.name).inserted {
                switch alias.closure {
                case .function(let escapes):
                    return current.escaping || escapes ? .escaping : .nonEscaping

                case let .named(next, escapes):
                    current = (next, current.escaping || escapes, table.position(of: alias, from: current.context))

                case .other:
                    return .nonClosure
                }
            }
            return .nonClosure

        case .other:
            return .nonClosure
        }
    }

    /// A bare name: a global, or a bare static.
    private func countName(_ name: RawName, into tally: inout CouplingTally) {
        switch resolveValue(name.name, lookup: name.lookup) {
        case .global(let global):
            if name.isTypePosition == false || CalleeReader.startsUppercase(name.name) == false {
                tally.addGlobal(global)
            } else if case .global(let candidate) = classifyCandidate(name.name, lookup: name.lookup) {
                tally.addGlobal(candidate)
            }

        case let .staticMember(owner, member):
            if member.kind.isProperty {
                tally.addStatic(owner: owner, member: member, kind: table.entries[owner]?.kind)
            }

        case .enumCase, .freeFunction, .inheritedMember, .notCoupling, .ownMember, .unresolved:
            break
        }
    }

    /// `Base.member` on a type, `Self` or this module.
    private func countMemberRead(_ read: RawMemberRead, into tally: inout CouplingTally) {
        guard Self.nonStaticMembers.contains(read.member) == false else {
            return
        }
        if read.baseIsSelfType {
            if let current = context.chain.first {
                countStatic(read.member, on: current, into: &tally)
            }
            return
        }
        guard let root = read.base.first else {
            return
        }
        if root.hasPrefix(Self.selectorMarker) {
            countResolvedRead(read, into: &tally)
            return
        }
        if read.base.count == 1, isThisModule(read.base) {
            if let global = table.global(read.member, from: context.file) {
                tally.addGlobal(global)
            }
            return
        }
        countTypeMemberRead(read, root: root, into: &tally)
    }

    /// `Base.member` whose root names a type or a module other than this one.
    private func countTypeMemberRead(_ read: RawMemberRead, root: String, into tally: inout CouplingTally) {
        switch resolveValue(root, lookup: read.rootLookup) {
        case .enumCase, .global, .inheritedMember, .notCoupling, .ownMember, .staticMember:
            return

        case .freeFunction, .unresolved:
            break
        }
        guard CalleeReader.startsUppercase(root) || context.knownModules.contains(root) else {
            return
        }
        countResolvedRead(read, into: &tally)
    }

    /// `Base.member` on a base that resolves as a type.
    private func countResolvedRead(_ read: RawMemberRead, into tally: inout CouplingTally) {
        switch table.resolve(spelledBase(read.base), from: context) {
        case .module(let key):
            countStatic(read.member, on: key, into: &tally)

        case .external(let name), .platform(let name):
            if Self.externalSingletonNames.contains(read.member) {
                tally.singletons.insert(name + "." + read.member)
            }

        case .ambiguous, .genericParameter, .opaqueAlias, .unresolved:
            break
        }
    }

    /// A static of a module type, or of its superclass chain.
    private func countStatic(_ name: String, on key: TypeKey, into tally: inout CouplingTally) {
        let matches = members(named: name, of: key).filter(\.member.isTypeLevel)
        guard let owner = matches.first(where: \.member.kind.isProperty)?.owner,
              let member = MemberFact.firstProperty(matches.filter { $0.owner == owner }.map(\.member)) else {
            return
        }
        tally.addStatic(owner: owner, member: member, kind: table.entries[owner]?.kind)
    }

    /// Whether `base` is `[ThisModule]` or `[::ThisModule]`: this module, not
    /// a module type named like it.
    func isThisModule(_ base: [String]) -> Bool {
        base == [Self.selectorMarker + table.module] || (base == [table.module] && isModuleQualifier(table.module))
    }

    /// `ThisModule.global` read as a type name: a global, not a type (Spec §7.3).
    private func isThisModuleGlobal(_ type: SpelledType) -> Bool {
        type.moduleSelector == table.module && type.components.count == 1
            && table.global(type.spelling, from: context.file) != nil
    }

    /// Whether `qualifier` names a module, not a module type of the same name.
    func isModuleQualifier(_ qualifier: String?) -> Bool {
        guard let qualifier, context.knownModules.contains(qualifier) else {
            return false
        }
        let asType = table.resolve(SpelledType(components: [qualifier], moduleSelector: nil), from: context)
        return asType.isModuleType == false
    }

    /// Whether `owner` declares a static method `name`, which a call would reach first.
    private func hasStaticMethod(_ name: String, labels: [String], on owner: TypeKey) -> Bool {
        members(named: name, of: owner).contains { match in
            match.member.isTypeLevel && match.member.kind == .function && match.member.labels == labels
        }
    }
}
