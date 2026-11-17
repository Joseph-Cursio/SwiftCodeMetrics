//
//  ResultSlots.swift
//  SwiftCodeMetrics
//
//  Write-once result slots for the parallel file passes.
//

import Foundation

/// Write-once slots filled from several threads, read after they all finish.
final class ResultSlots<Value: Sendable>: @unchecked Sendable {
    /// Guards `slots`.
    private let lock = NSLock()
    /// One slot per index.
    private var slots: [Value?]

    /// Every filled slot, in index order.
    var values: [Value] {
        lock.withLock { slots.compactMap(\.self) }
    }

    /// `count` empty slots.
    init(count: Int) {
        slots = Array(repeating: nil, count: count)
    }

    /// Fills slot `index`.
    func store(_ value: Value, at index: Int) {
        lock.withLock { slots[index] = value }
    }

    deinit {
        // Nothing to release beyond stored properties.
    }
}
