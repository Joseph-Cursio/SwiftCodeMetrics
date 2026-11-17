func timeout(override: Int?, environment: [String: String], config: Config?) -> Int {
    override
        ?? environment["TIMEOUT"].flatMap(Int.init)
        ?? config?.timeout
        ?? 30
}
