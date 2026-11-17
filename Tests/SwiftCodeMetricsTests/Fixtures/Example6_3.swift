func firstMatch(in grid: [[Int]], equalTo target: Int) -> (row: Int, col: Int)? {
    var found: (row: Int, col: Int)?
    outer: for (row, values) in grid.enumerated() {
        for (col, value) in values.enumerated() {
            if value == target {
                found = (row, col)
                break outer
            }
        }
    }
    return found
}
