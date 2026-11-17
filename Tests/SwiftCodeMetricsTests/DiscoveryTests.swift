//
//  DiscoveryTests.swift
//  SwiftCodeMetricsTests
//
//  Spec §2.1 and §13.1: which records exist, their kinds, keys, names,
//  parent links and order.
//

import SwiftCodeMetrics
import SwiftParser
import SwiftSyntax
import Testing

@Suite("Discovery (Spec §2.1)")
struct DiscoveryTests {
    private static let members = """
    struct S {
        var stored = 0
        var lazyValue = { if a { return 1 }; return 2 }()
        static let shared = b ?? c
        var computed: Int { 1 }
        var both: Int { get { 1 } set { } }
        var observed = 0 { didSet { } }
        init() { }
        deinit { }
        subscript(i: Int) -> Int { i }
        subscript(key key: String) -> Int { get { 0 } set { } }
        func method(_ x: Int, label y: Int) -> Int { x }
    }
    """

    @Test("every member kind becomes the right record")
    func memberKinds() {
        let records = Fixtures.analysis(source: Self.members).functions
        let summary = records.map { "\($0.kind) \($0.name)" }

        #expect(summary == [
            "propertyInitializer lazyValue.initializer",
            "propertyInitializer shared.initializer",
            "computedGetter computed.get",
            "accessor both.get",
            "accessor both.set",
            "accessor observed.didSet",
            "initializer init()",
            "deinitializer deinit",
            "subscriptGetter subscript(_:).get",
            "accessor subscript(key:).get",
            "accessor subscript(key:).set",
            "function method(_:label:)"
        ])
    }

    @Test("keys follow PRD §6.1, as SwiftStats renders them")
    func keys() {
        let records = Fixtures.analysis(source: Self.members).functions
        let keys = Dictionary(uniqueKeysWithValues: records.map { ($0.name, $0.key.description) })

        #expect(keys["method(_:label:)"] == "Lib::S::func method(_: Int, label: Int) -> Int")
        #expect(keys["computed.get"] == "Lib::S::var computed: Int { get }")
        #expect(keys["subscript(_:).get"] == "Lib::S::subscript(_: Int) -> Int")
        #expect(keys["subscript(key:).set"] == "Lib::S::subscript(key: String) -> Int / { set }")
        #expect(keys["lazyValue.initializer"] == "Lib::S::var lazyValue = <initializer>")
        #expect(keys["shared.initializer"] == "Lib::S::static let shared = <initializer>")
    }

    @Test("private declarations get the file; #if variants are separate records")
    func fileAndConditions() {
        let records = Fixtures.analysis(
            source: """
        private func helper() {}
        #if DEBUG
        func log() {}
        #else
        func log() {}
        #endif
        """,
            path: "Sources/A.swift"
        ).functions

        #expect(records.map(\.key.description) == [
            "Lib::func helper() @ Sources/A.swift",
            "Lib::func log() #if DEBUG",
            "Lib::func log() #if !(DEBUG)"
        ])
        #expect(records[0].key.file == "Sources/A.swift")
    }

    @Test("nested repeats are numbered and linked to their parent")
    func nestedRepeats() {
        let records = Fixtures.analysis(source: "func f() { if a { func g() {} } else { func g() {} } }").functions

        #expect(records.map(\.key.description) == [
            "Lib::func f()",
            "Lib::func f() / func g()",
            "Lib::func f() / func g() #2"
        ])
        #expect(records[1].parentID == 0)
        #expect(records[2].parentKey == records[0].key)
    }

    @Test("local types' members and initial values belong to the enclosing function")
    func localTypes() {
        let records = Fixtures.analysis(source: """
        func outer() {
            struct Local {
                var value = { if a { return 1 }; return 2 }()
                func m() {}
            }
        }
        """).functions

        #expect(records.map(\.name) == ["outer()", "value.initializer", "m()"])
        #expect(records.dropFirst().allSatisfy { $0.parentID == 0 })
        #expect(records[2].key.description == "Lib::func outer() / Local::func m()")
    }

    @Test("a func inside an unscored initial value is still a record, with no parent")
    func functionInInitialValue() {
        let source = "struct S { let make = { func build() -> Int { 1 }; return build() }() }"
        let records = Fixtures.analysis(source: source).functions

        #expect(records.map(\.key.description) == ["Lib::S::let make = <initializer> / func build() -> Int"])
        #expect(records[0].parentID == nil)
    }

    @Test("top-level code is one record; globals are not part of it")
    func topLevelCode() throws {
        let records = Fixtures.analysis(
            source: """
        let limit = a ? 1 : 2
        print(limit)
        func helper() { if a {} }
        if limit > 1 { do { func local() {} } }
        """,
            path: "main.swift"
        ).functions

        #expect(records.map(\.name) == ["limit.initializer", "<top-level code>", "local()", "helper()"])
        let topLevel = try #require(records.first { $0.kind == .topLevelCode })
        #expect(topLevel.complexity.cognitive == 1)
        #expect(topLevel.key.description == "Lib::<top-level code> @ main.swift")
        #expect(records[2].parentID == topLevel.id)
        #expect(topLevel.lines?.startLine == 2)
        #expect(topLevel.lines?.endLine == 4)
    }

    @Test("a file with no top-level statements has no top-level record")
    func noTopLevelCode() {
        let records = Fixtures.analysis(source: "func f() {}\nlet x = 1").functions

        #expect(records.map(\.kind) == [.function])
    }

    @Test("records are ordered pre-order, siblings by start offset (Spec §13.1)")
    func recordOrder() {
        let records = Fixtures.analysis(source: """
        func b() { func inner() {} }
        struct S { func a() {} }
        """).functions

        #expect(records.map(\.name) == ["b()", "inner()", "a()"])
        #expect(records.map(\.id) == [0, 1, 2])
    }

    @Test("the declaration form keys a member under its enclosing types")
    func declarationForm() throws {
        let tree = Parser.parse(source: "extension Outer { struct Inner { func run() { if a {} } } }")
        let finder = FirstFunction()
        finder.walk(tree)
        let function = try #require(finder.found)
        let analysis = SwiftCodeMetrics.functionMetrics(of: function, module: "Lib")

        #expect(analysis.functions.map(\.key.description) == ["Lib::Outer.Inner::func run()"])
        #expect(analysis.functions.first?.lines == nil)
        #expect(analysis.functions.first?.complexity.items.first?.line == nil)
        #expect(analysis.version == SwiftCodeMetrics.version)
    }

    @Test("functions in macro arguments are records")
    func macroArguments() {
        let records = Fixtures.analysis(source: "#Preview { struct V { func f() {} } }").functions

        #expect(records.map(\.name) == ["f()"])
    }

    @Test("coupling status says what v0.1 can't compute yet")
    func couplingStatus() {
        let records = Fixtures.analysis(source: Self.members).functions

        for record in records {
            let expected: CouplingStatus = record.kind == .propertyInitializer ? .notApplicableKind : .needsModulePass
            #expect(record.couplingStatus == expected, "\(record.name)")
        }
    }
}
