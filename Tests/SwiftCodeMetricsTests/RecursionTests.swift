//
//  RecursionTests.swift
//  SwiftCodeMetricsTests
//
//  Spec §3.4: direct recursion by syntax, its shadowing and label rules,
//  and the zero-amount possibleRecursion items.
//

import SwiftCodeMetrics
import Testing

@Suite("Recursion (Spec §3.4)")
struct RecursionTests {
    @Test(
        "direct recursion is found once per function",
        arguments: [
            "func f(a: Int, b: Int = 0) { f(a: 1); f(a: 1, b: 2) }",
            "func f(_ xs: Int...) { f(1, 2, 3) }",
            "func f(_ xs: Int...) { f() }",
            "func f() { self.f() }",
            "struct S { static func f() { Self.f() } }",
            "func f(by p: (Int) -> Bool) { f { $0 > 0 } }",
            "func f(_ xs: Int..., then: () -> Void) { f(1, 2, then: {}) }",
            "func f() { xs.forEach { _ in f() } }"
        ]
    )
    func direct(_ source: String) {
        let items = cognitiveItems(source)

        #expect(items.filter { $0.rule == .recursion }.map(\.amount) == [1])
    }

    @Test(
        "no recursion when shadowed, mislabelled or not an ordinary func",
        arguments: [
            "func apply(_ apply: (Int) -> Int) -> Int { apply(1) }",
            "func f() { let f = { }; f() }",
            "func f() { func f() {}; f() }",
            "func f(a: Int) { f(b: 1) }",
            "func f(a: Int) { f() }",
            "struct S { func f() { other.f() } }",
            "func f() { func g() { f() } }",
            "static func == (l: S, r: S) -> Bool { l == r }",
            "struct S { init() { self.init(x: 1) } }"
        ]
    )
    func none(_ source: String) {
        let items = cognitiveItems(source)

        #expect(items.contains { $0.rule == .recursion } == false)
    }

    @Test("a call on another receiver with fitting labels is a zero-amount possibleRecursion item")
    func possible() {
        let items = cognitiveItems("""
        func sorted(by areInIncreasingOrder: (Int, Int) -> Bool) -> [Int] {
            other.sorted { $0 < $1 } + left.sorted(by: <)
        }
        """)
        let possible = items.filter { $0.rule == .possibleRecursion }

        #expect(possible.count == 2)
        #expect(possible.allSatisfy { $0.amount == 0 })
    }

    @Test("possibleRecursion needs every parameter used")
    func possibleIsStrict() {
        let items = cognitiveItems("""
        func filter(_ a: Int, _ b: Int) { xs.filter { $0 > 0 } }
        func g(a: Int, b: Int = 0) { x.g(a: 1) }
        struct S { func h() { Self.h() } }
        """)

        #expect(items.filter { $0.rule == .possibleRecursion }.count == 1)
    }

    @Test("detectRecursion off removes both kinds of item")
    func optionOff() throws {
        var options = MetricsOptions()
        options.complexity.detectRecursion = false
        let analysis = Fixtures.analysis(source: "func f() { f(); x.f() }", options: options)
        let record = try #require(analysis.functions.first)

        #expect(record.complexity.items.isEmpty)
    }

    private func cognitiveItems(_ source: String) -> [Increment] {
        Fixtures.analysis(source: source).functions.flatMap(\.complexity.items).filter { $0.metric == .cognitive }
    }
}
