//
//  FunctionResolver+Calls.swift
//  SwiftCodeMetrics
//
//  Call keys (Spec §7.5) and fan-out (Spec §8.1).
//

extension FunctionResolver {
    /// Fan-out and its breakdown.
    func fanOut() -> FanOut {
        var grouped: [String: (site: CallSite, count: Int)] = [:]
        for call in raw.calls {
            guard let site = callSite(call) else {
                continue
            }
            if let existing = grouped[site.key] {
                let first = existing.site.offset <= site.offset ? existing.site : site
                grouped[site.key] = (first, existing.count + 1)
            } else {
                grouped[site.key] = (site, 1)
            }
        }
        let sites = grouped.values.sorted { ($0.site.offset, $0.site.key) < ($1.site.offset, $1.site.key) }
        let headline = sites.filter { $0.site.receiver != .implicitMember && $0.site.receiver != .chain }
        var byReceiver: [ReceiverKind: Int] = [:]
        for entry in sites {
            byReceiver[entry.site.receiver, default: 0] += 1
        }
        return FanOut(
            fanOut: headline.count,
            fanOutImplicitMember: byReceiver[.implicitMember] ?? 0,
            fanOutChained: byReceiver[.chain] ?? 0,
            byReceiver: byReceiver,
            distinctBaseNames: Set(headline.map(\.site.name)).count,
            macroExpansionCount: raw.macroExpansionCount,
            calls: sites.map { entry in
                CallKeyItem(
                    key: entry.site.key,
                    receiver: entry.site.receiver,
                    siteCount: entry.count,
                    firstUTF8Offset: entry.site.offset
                )
            }
        )
    }

    /// A call's key, or nil when the call is excluded (Spec §8.1).
    func callSite(_ call: RawCall) -> CallSite? {
        let suffix = call.name + "(" + call.labels.map { $0 + ":" }.joined() + ")"
        func site(_ receiver: ReceiverKind, _ prefix: String) -> CallSite {
            CallSite(key: prefix + suffix, receiver: receiver, name: call.name, offset: call.offset)
        }
        switch call.shape {
        case .bare(let lookup):
            return bareSite(call, lookup: lookup, site: site)

        case .chain:
            return site(.chain, "chain.")

        case .implicitMember:
            return site(.implicitMember, "..")

        case .other:
            return site(.unknown, "?.")

        case let .qualified(base, rootLookup):
            return qualifiedSite(call, base: base, rootLookup: rootLookup, site: site)

        case .selfMember:
            return site(.`self`, "self.")

        case .selfType:
            let path = context.chain.first?.path.joined(separator: ".") ?? "Self"
            guard call.name != "init", CalleeReader.startsUppercase(call.name) else {
                return site(.type, path + ".")
            }
            // `Self.Inner(...)` constructs the nested type (Spec §7.5).
            let spelled = path + "." + call.name
            let nested = table.resolve(SpelledType(components: ["Self", call.name], moduleSelector: nil), from: context)
            return initSite(call, typeName: nested == .unresolved ? spelled : typeName(nested, spelled: spelled))

        case .superMember:
            return site(.`super`, "super.")
        }
    }

    /// The display name of a resolved type, for `T` keys.
    func typeName(_ resolution: TypeResolution, spelled: String) -> String {
        switch resolution {
        case .module(let key):
            key.path.joined(separator: ".")

        case .external(let name), .platform(let name):
            name

        case .ambiguous, .genericParameter, .opaqueAlias, .unresolved:
            spelled
        }
    }

    /// An unqualified callee.
    private func bareSite(
        _ call: RawCall,
        lookup: [StoredLookupResult],
        site: (ReceiverKind, String) -> CallSite
    ) -> CallSite? {
        // `T()` on a generic parameter is keyed like `T.init()` (Spec §7.5).
        if CalleeReader.startsUppercase(call.name), context.genericParameters.contains(call.name),
           lookup.first == .local {
            return initSite(call, typeName: call.name)
        }
        let value = resolveValue(call.name, lookup: lookup)
        switch value {
        case .notCoupling:
            return nil

        case .inheritedMember, .ownMember:
            return site(.`self`, "self.")

        case let .staticMember(owner, _):
            return site(.type, owner.path.joined(separator: ".") + ".")

        case .enumCase(let owner):
            return site(.type, owner.path.joined(separator: ".") + ".")

        case .freeFunction, .global, .unresolved:
            break
        }
        if CalleeReader.startsUppercase(call.name) {
            return candidateSite(call, lookup: lookup, site: site)
        }
        if table.isFreeFunction(call.name, from: context.file) {
            return site(.free, "free.")
        }
        if options.diagnosticFreeFunctions.contains(call.name) {
            return nil
        }
        let isFree = isPlatformFreeFunction(call.name)
        return site(isFree ? .free : .implicit, isFree ? "free." : "implicit.")
    }

    /// An uppercase unqualified callee: a type's initialiser, a free function or neither.
    private func candidateSite(
        _ call: RawCall,
        lookup: [StoredLookupResult],
        site: (ReceiverKind, String) -> CallSite
    ) -> CallSite {
        switch classifyCandidate(call.name, lookup: lookup) {
        case .type(let resolution):
            return initSite(call, typeName: typeName(resolution, spelled: call.name))

        case .freeFunction:
            return site(.free, "free.")

        case .global, .notCandidate:
            return site(.implicit, "implicit.")
        }
    }

    /// A callee on a dotted base: a module qualifier, a type, or a value.
    private func qualifiedSite(
        _ call: RawCall,
        base: [String],
        rootLookup: [StoredLookupResult],
        site: (ReceiverKind, String) -> CallSite
    ) -> CallSite? {
        guard let root = base.first else {
            return site(.unknown, "?.")
        }
        let isSelector = root.hasPrefix(Self.selectorMarker)
        if base.count == 1, isSelector || isModuleQualifier(root) {
            // A `Module::` selector always names a module; `Lib.f()` does
            // only when no module type is named `Lib`.
            let module = isSelector ? String(root.dropFirst(Self.selectorMarker.count)) : root
            return moduleSite(call, module: module, site: site)
        }
        if isSelector == false, isValueRoot(root, lookup: rootLookup) {
            return site(.unknown, "?.")
        }
        let resolution = table.resolve(spelledBase(base), from: context)
        switch resolution {
        case .genericParameter:
            // `T.init()` and `T.make()` on a generic parameter, like `T()`.
            return typeSite(call, owner: displayBase(base), base: base, site: site)

        case .ambiguous, .external, .opaqueAlias, .platform, .unresolved:
            // `FileManager.default.x()`: a static property, not a type, is the receiver.
            let afterRoot = spelledBase(base).components.drop { context.knownModules.contains($0) }.dropFirst()
            guard afterRoot.allSatisfy(CalleeReader.startsUppercase) else {
                return site(.unknown, "?.")
            }
            let owner = typeName(resolution, spelled: displayBase(base))
            return typeSite(call, owner: owner, base: base, site: site)

        case .module:
            let owner = typeName(resolution, spelled: displayBase(base))
            return typeSite(call, owner: owner, base: base, site: site)
        }
    }

    /// `M.f(...)` and `M::f(...)`: `f` classified as an unqualified callee of
    /// module `M` (Spec §7.5 step 2).
    private func moduleSite(_ call: RawCall, module: String, site: (ReceiverKind, String) -> CallSite) -> CallSite? {
        guard CalleeReader.startsUppercase(call.name) else {
            return bareSite(call, lookup: [], site: site)
        }
        let resolved = table.resolve(SpelledType(components: [call.name], moduleSelector: module), from: context)
        if module == table.module {
            return thisModuleSite(call, resolved: resolved, site: site)
        }
        // `Foundation.NSLog(...)`: an uppercase platform free function, not a type.
        if resolved.isPlatformType == false, isPlatformFreeFunction(call.name),
           PlatformModules.harvested.contains(module) || module == PlatformModules.xcTest {
            return site(.free, "free.")
        }
        return initSite(call, typeName: typeName(resolved, spelled: call.name))
    }

    /// `Lib.X(...)` in module `Lib`: `X` at module top level, never a nested
    /// type of the current one, by the candidate order of Spec §7.3.
    private func thisModuleSite(
        _ call: RawCall,
        resolved: TypeResolution,
        site: (ReceiverKind, String) -> CallSite
    ) -> CallSite {
        switch resolved {
        case .ambiguous, .genericParameter, .module, .opaqueAlias, .platform:
            return initSite(call, typeName: typeName(resolved, spelled: call.name))

        case .external, .unresolved:
            if table.isFreeFunction(call.name, from: context.file) || isPlatformFreeFunction(call.name) {
                return site(.free, "free.")
            }
            if table.global(call.name, from: context.file) != nil {
                return site(.implicit, "implicit.")
            }
            return initSite(call, typeName: typeName(resolved, spelled: call.name))
        }
    }

    /// A call on a type: a static, or `Owner.Inner(...)`, which constructs the
    /// nested type and is keyed `Owner.Inner.init` (Spec §7.5).
    private func typeSite(
        _ call: RawCall,
        owner: String,
        base: [String],
        site: (ReceiverKind, String) -> CallSite
    ) -> CallSite {
        guard CalleeReader.startsUppercase(call.name) else {
            return site(.type, owner + ".")
        }
        let nested = table.resolve(spelledBase(base + [call.name]), from: context)
        let spelled = owner + "." + call.name
        return initSite(call, typeName: nested == .unresolved ? spelled : typeName(nested, spelled: spelled))
    }

    /// Whether a dotted base's root is a value, not a type or a module: then
    /// the receiver is `?`.
    private func isValueRoot(_ root: String, lookup: [StoredLookupResult]) -> Bool {
        if CalleeReader.startsUppercase(root), context.genericParameters.contains(root) {
            return false
        }
        switch resolveValue(root, lookup: lookup) {
        case .enumCase, .global, .inheritedMember, .notCoupling, .ownMember, .staticMember:
            return true

        case .freeFunction, .unresolved:
            return (CalleeReader.startsUppercase(root) || context.knownModules.contains(root)) == false
        }
    }

    /// `Type.init(labels)`.
    private func initSite(_ call: RawCall, typeName: String) -> CallSite {
        CallSite(
            key: typeName + ".init(" + call.labels.map { $0 + ":" }.joined() + ")",
            receiver: .type,
            name: "init",
            offset: call.offset
        )
    }
}
