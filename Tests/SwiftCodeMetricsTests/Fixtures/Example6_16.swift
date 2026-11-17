func render(_ rows: [Row]) -> String {
    func cell(_ value: Int?) -> String {
        guard let value else { return "-" }
        return value < 0 ? "(\(-value))" : "\(value)"
    }
    return rows
        .map { row in row.values.map(cell).joined(separator: " | ") }
        .joined(separator: "\n")
}
