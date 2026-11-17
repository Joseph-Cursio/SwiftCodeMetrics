func firstValidToken(in lines: [String], strict: Bool) -> Token? {
    for line in lines {
        guard !line.isEmpty else { continue }
        guard let token = Token(line) else {
            if strict {
                log("bad token: \(line)")
            }
            continue
        }
        guard token.isSigned || !strict else { continue }
        return token
    }
    return nil
}
