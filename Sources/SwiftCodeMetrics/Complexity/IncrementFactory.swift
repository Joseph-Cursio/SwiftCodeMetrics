//
//  IncrementFactory.swift
//  SwiftCodeMetrics
//
//  Builds breakdown items anchored on a token, adding line and column when
//  the caller supplied locations.
//

import SwiftSyntax

/// Makes `Increment` values for one file.
struct IncrementFactory {
    /// Converts offsets to lines and columns; nil when locations are unknown.
    let converter: SourceLocationConverter?

    /// An item of `amount` with no nesting part, anchored at the start of `anchor`.
    func make(_ metric: Increment.Metric, _ rule: Increment.Rule, amount: Int, anchor: TokenSyntax) -> Increment {
        build(metric, rule, amount: amount, anchor: anchor, nesting: (0, 0))
    }

    /// A cognitive structural item: 1 plus `nesting`, of which `closureNesting`
    /// comes from enclosing closures.
    func structural(_ rule: Increment.Rule, anchor: TokenSyntax, nesting: Int, closureNesting: Int) -> Increment {
        build(.cognitive, rule, amount: 1 + nesting, anchor: anchor, nesting: (nesting, closureNesting))
    }

    /// The item, with its location when known.
    private func build(
        _ metric: Increment.Metric,
        _ rule: Increment.Rule,
        amount: Int,
        anchor: TokenSyntax,
        nesting: (levels: Int, closures: Int)
    ) -> Increment {
        let position = anchor.positionAfterSkippingLeadingTrivia
        let location = converter?.location(for: position)
        return Increment(
            metric: metric,
            rule: rule,
            amount: amount,
            nesting: nesting.levels,
            closureNesting: nesting.closures,
            utf8Offset: position.utf8Offset,
            line: location?.line,
            column: location?.column
        )
    }
}
