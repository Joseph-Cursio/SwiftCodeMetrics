func probe(_ c: Int) -> Int {
    guard let a = Optional(c), c > 1 else { return 0 }
    for x in [1, 2] where x > 0 { print(x) }
    switch c {
    case 1, 2: return 1
    case 3 where a > 2: return 2
    default: break
    }
    return c > 0 ? 1 : 2
}
