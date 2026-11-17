//
//  CouplingExampleTests.swift
//  SwiftCodeMetricsTests
//
//  Spec §16 v0.2 golden tests: the function-level values of §12.1–12.5 —
//  fan-out with its separate counts, common coupling and parameter counts.
//

import SwiftCodeMetrics
import Testing

@Suite("Coupling worked examples (Spec §12.1–12.5)")
struct CouplingExampleTests {
    @Test("12.1: fan-out across an extension in another file")
    func shop() {
        let analysis = Modules.analysis("Shop", CouplingSources.shop)

        #expect(Modules.headline(Modules.record("add(_:)", in: analysis)) == ["?.append(_:)", "self.touch()"])
        #expect(Modules.headline(Modules.record("touch()", in: analysis)) == ["Date.init()"])
        #expect(Modules.headline(Modules.record("totalPrice.get", in: analysis)) == ["?.reduce(_:_:)"])
        let description = Modules.record("description.get", in: analysis)
        #expect(description?.fanOut?.fanOut == 0)
        let add = Modules.record("add(_:)", in: analysis)
        #expect(add?.typeReferences.map(\.spelling) == ["Item"])
        #expect(add?.typeReferences.first?.target == TypeKey(module: "Shop", path: ["Item"]))
        let isStale = Modules.record("isStale(after:)", in: analysis)
        #expect(Modules.headline(isStale) == ["Date.init()"])
        #expect(Modules.keys(isStale, .chain) == ["chain.timeIntervalSince(_:)"])
        #expect(isStale?.fanOut?.fanOutChained == 1)
        #expect(isStale?.fanOut?.fanOutImplicitMember == 0)
        #expect(isStale?.typeReferences.map(\.spelling) == ["TimeInterval", "Bool", "Date"])
        #expect(isStale?.typeReferences.allSatisfy { $0.bucket == .platform } == true)
    }

    @Test("12.2: fan-out in a class with two cohesion groups")
    func session() {
        let analysis = Modules.analysis("App", CouplingSources.session)
        let signIn = Modules.record("signIn(token:validFor:)", in: analysis)

        #expect(Modules.headline(signIn) == ["Date.init()"])
        #expect(Modules.keys(signIn, .chain) == ["chain.addingTimeInterval(_:)"])
        let recordSearch = Modules.record("record(search:)", in: analysis)
        #expect(Modules.headline(recordSearch) == ["?.insert(_:at:)", "self.trimRecent()"])
        #expect(Modules.headline(Modules.record("trimRecent()", in: analysis)) == ["?.removeLast(_:)"])
        #expect(Modules.headline(Modules.record("clearSearches()", in: analysis)) == ["?.removeAll()"])
        #expect(Modules.headline(Modules.record("isSignedIn.get", in: analysis)) == ["Date.init()"])
        #expect(Modules.record("signOut()", in: analysis)?.fanOut?.fanOut == 0)
    }

    @Test("12.3: implicit members, a platform free function and parameter counts")
    func formatter() {
        let analysis = Modules.analysis("App", CouplingSources.formatter)
        let format = Modules.record("format(_:)", in: analysis)
        let formatRange = Modules.record("formatRange(_:_:)", in: analysis)
        let rounded = Modules.record("rounded(_:)", in: analysis)

        #expect(Modules.headline(format) == ["?.formatted(_:)"])
        #expect(Modules.keys(format, .implicitMember) == ["..currency(code:)"])
        #expect(Modules.headline(formatRange) == ["self.format(_:)"])
        #expect(formatRange?.fanOut?.calls.first?.siteCount == 2)
        #expect(Modules.headline(rounded) == ["Decimal.init()", "free.NSDecimalRound(_:_:_:_:)"])
        #expect(formatRange?.parameters?.parameterCount == 2)
        #expect(rounded?.parameters?.parameterCount == 1)
        #expect(rounded?.parameters?.inoutParameterCount == 0)
    }

    @Test("12.4: globals, statics and a singleton")
    func app() {
        let analysis = Modules.analysis("App", CouplingSources.app)
        let load = Modules.record("load(userID:)", in: analysis)
        let coupling = load?.commonCoupling

        #expect(coupling?.globals == ["defaultTimeout", "requestCount"])
        #expect(coupling?.mutableGlobals == ["requestCount"])
        #expect(coupling?.statics == ["APIClient.shared", "APIClient.verbose"])
        #expect(coupling?.mutableStatics == ["APIClient.verbose"])
        #expect(coupling?.singletons == ["APIClient.shared"])
        #expect(Modules.headline(load) == ["?.send(_:)", "JSONDecoder.init()", "URLRequest.init(url:)"])
        #expect(Modules.keys(load, .chain) == ["chain.decode(_:from:)"])
    }

    @Test("12.5: an initialiser call and an unresolved protocol default")
    func shapes() {
        let analysis = Modules.analysis("App", CouplingSources.shapes)

        #expect(Modules.headline(Modules.record("scaled(by:)", in: analysis)) == ["Circle.init(radius:)"])
        for name in ["describe()", "area.get", "name.get"] {
            #expect(Modules.record(name, in: analysis)?.fanOut?.fanOut == 0, "\(name)")
        }
    }
}
