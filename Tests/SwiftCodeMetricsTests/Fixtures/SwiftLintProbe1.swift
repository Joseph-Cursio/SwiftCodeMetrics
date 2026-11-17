func outer(_ xs: [Int]) -> Int {
    struct Local {
        var v: Int { if a { return 1 } else { return 2 } }
        subscript(i: Int) -> Int { if i > 0 { return 1 }; return 0 }
        deinit { if b { print(1) } }
        func m() { if c { print(2) } }
        init() { if d { print(3) } }
    }
    var local: Int { if e { return 1 }; return 0 }
    var obs = 0 { didSet { if f { print(4) } } }
    xs.forEach { if $0 > 0 { print($0) } }
    return 0
}
struct S {
    var g: Int { if a { return 1 }; return 0 }
    var h: Int { get { if a { return 1 }; return 0 } set { if b { } } }
    deinit { if a { } }
    subscript(i: Int) -> Int { if a { return 1 }; return 0 }
}
func q(_ xs: [Int?]) {
    for case let x? in xs where x > 0 && x < 9 { print(x) }
    if a && b || c, d { }
    let z = a ?? b
    while let y = it.next(), y > 0 { }
}
func noCases(_ n: Never) { switch n {} }
