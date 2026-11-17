func a1() -> Int {
    struct L {
        var x: Int = { if c { return 1 }; return 2 }()
        #if DEBUG
        var y: Int { if d { return 1 }; return 0 }
        #endif
    }
    return 0
}
func a2(_ pairs: [(Int, Int)]) {
    for case let (p, q) in pairs { print(p, q) }
}
func a3(_ n: Int) -> Int {
    switch n {
    #if DEBUG
    case 1: return 1
    case 2: return 2
    #else
    case 3: return 3
    #endif
    default: return 0
    }
}
func a4(_ n: Int) -> Int {
    func inner(_ k: Int = { if z { return 1 }; return 2 }()) -> Int { k }
    return inner()
}
