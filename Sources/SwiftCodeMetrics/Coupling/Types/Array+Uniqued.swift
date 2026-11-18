//
//  Array+Uniqued.swift
//  SwiftCodeMetrics
//
//  Order-preserving de-duplication.
//

extension Array where Element: Hashable {
    /// The elements without repeats, first occurrence kept.
    func uniqued() -> [Element] {
        var seen: Set<Element> = []
        return filter { seen.insert($0).inserted }
    }
}
