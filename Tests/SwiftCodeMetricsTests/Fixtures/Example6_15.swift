func priority(of statusCode: Int) -> Int {
    var score = 0
    switch statusCode {
    case 500...:
        score += 10
        fallthrough
    case 400..<500:
        score += 5
    case 0:
        fallthrough
    case 1:
        score = 1
    default:
        break
    }
    return score
}
