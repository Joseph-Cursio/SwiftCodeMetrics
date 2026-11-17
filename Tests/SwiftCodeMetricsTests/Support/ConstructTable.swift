//
//  ConstructTable.swift
//  SwiftCodeMetricsTests
//
//  At least one case per row of the §3.2 construct table and the §4.2
//  decision table. Free names need not resolve: the library reads syntax.
//

/// The construct cases.
enum ConstructTable {
    /// Every case.
    static let all: [ConstructCase] = functions + branches + switches + loops + errors + jumps + operators + directives

    private static let functions: [ConstructCase] = [
        ConstructCase("3.2 #1", "func f() {}", expect: "C 0 D 0 SL 0"),
        ConstructCase("3.2 #2 parent", "func f() { func g() { if a {} } }", expect: "C 0 D 0 SL 0"),
        ConstructCase("3.2 #2 nested", "func f() { func g() { if a {} } }", function: "g()", expect: "C 1 D 1 SL 1"),
        ConstructCase(
            "3.2 #3 local type",
            "func f() { struct L { func m() { if a {} }; var v: Int { if a { return 1 }; return 0 } } }",
            expect: "C 0 D 0 SL 1"
        ),
        ConstructCase(
            "3.2 #3 local computed",
            "func f() { var x: Int { if a { return 1 }; return 0 } }",
            expect: "C 0 D 0 SL 1"
        ),
        ConstructCase("3.2 #3 local observer", "func f() { var y = 0 { didSet { if a {} } } }", expect: "C 0 D 0 SL 1"),
        ConstructCase("3.2 #4, #11", "func f() { xs.forEach { if a {} } }", expect: "C 2 D 1 SL 1"),
        ConstructCase(
            "3.2 #4 interpolation",
            #"func f() { print("\({ if a { 1 } else { 2 } }())") }"#,
            expect: "C 3 D 1 SL 1"
        ),
        ConstructCase("3.2 #5", "func f() { Task { if a {} } }", expect: "C 2 D 1 SL 1"),
        ConstructCase("3.2 #6", "func f() async { async let x = g() }", expect: "C 0 D 0 SL 0"),
        ConstructCase(
            "3.2 #7",
            "func f() async throws { for try await x in s { await g(x) } }",
            expect: "C 1 D 1 SL 1"
        ),
        ConstructCase("3.2 #8", "func f() { defer { if a {} } }", expect: "C 2 D 1 SL 1"),
        ConstructCase(
            "3.2 #9",
            "@ViewBuilder func f() -> some View { if a { A() } else { B() } }",
            expect: "C 2 D 1 SL 1"
        ),
        ConstructCase("3.2 #10", "func f() -> some View { VStack { if a { A() } } }", expect: "C 2 D 1 SL 1")
    ]

    private static let branches: [ConstructCase] = [
        ConstructCase("3.2 #12, 4.2 if", "func f() { if a {} }", expect: "C 1 D 1 SL 1"),
        ConstructCase("3.2 #13", "func f() { let v = if c { 1 } else { 2 } }", expect: "C 2 D 1 SL 1"),
        ConstructCase("3.2 #14, 4.2 else if", "func f() { if a {} else if b {} }", expect: "C 2 D 2 SL 2"),
        ConstructCase("3.2 #15, 4.2 else", "func f() { if a {} else {} }", expect: "C 2 D 1 SL 1"),
        ConstructCase(
            "3.2 #16 in a loop",
            "func f() { for x in xs { guard x else { continue } } }",
            expect: "C 2 D 2 SL 2"
        ),
        ConstructCase("3.2 #16 else nests", "func f() { guard a else { if b {}; return } }", expect: "C 3 D 2 SL 2"),
        ConstructCase("3.2 #17, 4.2 extra elements", "func f() { if a, b, c {} }", expect: "C 2 D 3 SL 1"),
        ConstructCase("3.2 #18, 4.2 binding", "func f() { if let x = y {} }", expect: "C 1 D 1 SL 1"),
        ConstructCase("3.2 #18 while let", "func f() { while let x = it.next() {} }", expect: "C 1 D 1 SL 1"),
        ConstructCase("3.2 #19, 4.2 if case", "func f() { if case .a = x {} }", expect: "C 1 D 1 SL 1"),
        ConstructCase("3.2 #20 alone", "func f() { if #available(macOS 14, *) {} }", expect: "C 1 D 1 SL 1"),
        ConstructCase("3.2 #20 in a list", "func f() { if #available(macOS 14, *), a {} }", expect: "C 2 D 2 SL 1"),
        ConstructCase("3.2 #54", "func f() { if case let x? = y {} }", expect: "C 1 D 1 SL 1"),
        ConstructCase("3.2 #68", "func f() { while true {}; if true {} }", expect: "C 2 D 2 SL 2")
    ]

    private static let switches: [ConstructCase] = [
        ConstructCase(
            "3.2 #21, #22, 4.2 switch",
            "func f() { switch x { case 1: break; default: break } }",
            expect: "C 1 D 1 SL 2"
        ),
        ConstructCase(
            "4.2 switch, no arms",
            "func f(_ n: Never) { switch n {} }",
            function: "f(_:)",
            expect: "C 1 D 0 SL 0"
        ),
        ConstructCase(
            "3.2 #23, 4.2 multi-pattern",
            "func f() { switch x { case 1, 2: break; default: break } }",
            expect: "C 1 D 1 SL 2"
        ),
        ConstructCase(
            "3.2 #24, 4.2 where on case",
            "func f() { switch x { case let y where y > 0 && y < 9: break; default: break } }",
            expect: "C 2 D 3 SL 2"
        ),
        ConstructCase(
            "3.2 #25 after code",
            "func f() { switch x { case 1: g(); fallthrough; default: break } }",
            expect: "C 2 D 1 SL 1"
        ),
        ConstructCase(
            "3.2 #25 inside an if",
            "func f() { switch x { case 1: if a { fallthrough }; default: break } }",
            expect: "C 4 D 2 SL 2"
        ),
        ConstructCase(
            "3.2 #26, 4.2 fallthrough-only arm",
            "func f() { switch x { case 0: fallthrough; case 1: break; default: break } }",
            expect: "C 1 D 1 SL 2"
        )
    ]

    private static let loops: [ConstructCase] = [
        ConstructCase("3.2 #29, 4.2 for", "func f() { for x in xs {} }", expect: "C 1 D 1 SL 1"),
        ConstructCase(
            "3.2 #30, 4.2 refutable for case",
            "func f() { for case let x? in xs {} }",
            expect: "C 1 D 2 SL 1"
        ),
        ConstructCase("4.2 irrefutable for case", "func f() { for case let (a, _) in xs {} }", expect: "C 1 D 1 SL 1"),
        ConstructCase(
            "4.2 irrefutable for case, inner let",
            "func f() { for case (let a, let b) in xs {} }",
            expect: "C 1 D 1 SL 1"
        ),
        ConstructCase("4.2 irrefutable for case, discard", "func f() { for case _ in xs {} }", expect: "C 1 D 1 SL 1"),
        ConstructCase(
            "4.2 refutable for case, enum",
            "func f() { for case .some(let x) in xs {} }",
            expect: "C 1 D 2 SL 1"
        ),
        ConstructCase(
            "3.2 #31, 4.2 where on for",
            "func f() { for x in xs where x > 0 && x < 9 {} }",
            expect: "C 2 D 3 SL 1"
        ),
        ConstructCase("3.2 #32, 4.2 while", "func f() { while a, b {} }", expect: "C 2 D 2 SL 1"),
        ConstructCase("3.2 #33, 4.2 repeat", "func f() { repeat { if a {} } while b }", expect: "C 3 D 2 SL 2"),
        ConstructCase(
            "3.2 #34, 4.2 repeat each",
            "func f<each T>(_ t: repeat each T) { print(repeat each t) }",
            function: "f(_:)",
            expect: "C 0 D 0 SL 0"
        ),
        ConstructCase("4.2 forEach", "func f() { xs.forEach { _ in } }", expect: "C 0 D 0 SL 0")
    ]

    private static let errors: [ConstructCase] = [
        ConstructCase("3.2 #35, 4.2 do", "func f() { do { g() } }", expect: "C 0 D 0 SL 0"),
        ConstructCase("3.2 #36, 4.2 catch", "func f() { do { try g() } catch { if a {} } }", expect: "C 3 D 2 SL 2"),
        ConstructCase(
            "3.2 #37, 4.2 catch A, B",
            "func f() { do { try g() } catch is A, is B {} }",
            expect: "C 1 D 1 SL 1"
        ),
        ConstructCase(
            "3.2 #38, 4.2 where on catch",
            "func f() { do { try g() } catch let e where e.x && e.y {} }",
            expect: "C 2 D 3 SL 1"
        ),
        ConstructCase(
            "3.2 #39–#41, 4.2 try",
            "func f() throws { try g(); _ = try? g(); try! g() }",
            expect: "C 0 D 0 SL 0"
        ),
        ConstructCase(
            "3.2 #42, #43, 4.2 throw",
            "func f() throws { if a { throw E.x }; return }",
            expect: "C 1 D 1 SL 1"
        )
    ]

    private static let jumps: [ConstructCase] = [
        ConstructCase("3.2 #44", "func f() { for x in xs { if x { break }; continue } }", expect: "C 3 D 2 SL 2"),
        ConstructCase(
            "3.2 #45, #46",
            "func f() { outer: for x in xs { for y in ys { continue outer } } }",
            expect: "C 4 D 2 SL 2"
        ),
        ConstructCase("3.2 #45 break", "func f() { outer: while a { break outer } }", expect: "C 2 D 1 SL 1"),
        ConstructCase(
            "3.2 #47",
            "struct S { var v: Int { _read { yield x } } }",
            function: "v._read",
            expect: "C 0 D 0 SL 0"
        ),
        ConstructCase(
            "3.2 #48",
            "func f() { let y = consume x; let z = copy y; _ = unsafe z }",
            expect: "C 0 D 0 SL 0"
        ),
        ConstructCase(
            "3.2 #65, #66",
            "func depth(of n: Node) -> Int { n.left.depth(of: n) + depth(of: n) }",
            function: "depth(of:)",
            expect: "C 1 D 0 SL 0"
        ),
        ConstructCase("3.2 #67", "struct S { init() { self.init(x: 1) } }", function: "init()", expect: "C 0 D 0 SL 0")
    ]

    private static let operators: [ConstructCase] = [
        ConstructCase("3.2 #27, 4.2 ternary", "func f() { let v = a ? 1 : 2 }", expect: "C 1 D 1 SL 0"),
        ConstructCase("3.2 #28", "func f() { let v = a ? 1 : b ? 2 : 3 }", expect: "C 3 D 2 SL 0"),
        ConstructCase("3.2 #49, 4.2 && ||", "func f() { let v = a && b || c }", expect: "C 2 D 2 SL 0"),
        ConstructCase("3.2 #50 parentheses", "func f() { let v = a && (b && c) }", expect: "C 1 D 2 SL 0"),
        ConstructCase("3.2 #50 unsafe", "func f() { let v = unsafe (a && b) && c }", expect: "C 1 D 2 SL 0"),
        ConstructCase(
            "3.2 #50 try await",
            "func f() async throws { let v = try await (a && b) && c }",
            expect: "C 1 D 2 SL 0"
        ),
        ConstructCase("3.2 #51", "func f() { let v = a && !(b && c) }", expect: "C 2 D 2 SL 0"),
        ConstructCase("3.2 #52, 4.2 ??", "func f() { let v = a && b ?? c && d }", expect: "C 1 D 3 SL 0"),
        ConstructCase("3.2 #53, 4.2 ?.", "func f() { a?.b?.c() }", expect: "C 0 D 0 SL 0"),
        ConstructCase(
            "3.2 #55, 4.2 as! is",
            "func f() { let v = x! as! T; let w = y is U; let z = q as? V }",
            expect: "C 0 D 0 SL 0"
        ),
        ConstructCase(#"3.2 #56"#, #"func f() { let k = \A.b?.c }"#, expect: "C 0 D 0 SL 0"),
        ConstructCase("3.2 #57", "func f() { let v = a < b + c }", expect: "C 0 D 0 SL 0"),
        ConstructCase("3.2 #58", "func f() { a && b = c && d }", expect: "C 2 D 2 SL 0")
    ]

    private static let directives: [ConstructCase] = [
        ConstructCase(
            "3.2 #59 in a case list",
            "func f() {\n switch x {\n #if DEBUG\n case 1: if a {}\n #endif\n default: break\n }\n}",
            expect: "C 6 D 2 SL 3"
        ),
        ConstructCase(
            "3.2 #59 postfix",
            "func f() {\n let v = x\n #if DEBUG\n .debug()\n #endif\n}",
            expect: "C 1 D 0 SL 0"
        ),
        ConstructCase("3.2 #61", "func f() {\n #if os(iOS) && DEBUG\n g()\n #endif\n}", expect: "C 1 D 0 SL 0"),
        ConstructCase(
            "4.2 #if tie",
            "func f() {\n #if A\n if a {}\n #else\n if b {}\n #endif\n}",
            expect: "C 6 D 1 SL 2"
        ),
        ConstructCase("4.2 #if no else", "func f() {\n #if A\n if a, b {}\n #endif\n}", expect: "C 4 D 2 SL 1"),
        ConstructCase("3.2 #62 macro argument", "func f() { #expect(a && b) }", expect: "C 1 D 1 SL 0"),
        ConstructCase("3.2 #62 macro closure", "func f() { #m { if a {} } }", expect: "C 2 D 1 SL 1"),
        ConstructCase("3.2 #63", "@MainActor func f() {}", expect: "C 0 D 0 SL 0")
    ]
}
