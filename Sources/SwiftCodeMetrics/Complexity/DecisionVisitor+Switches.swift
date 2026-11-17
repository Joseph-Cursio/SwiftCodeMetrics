//
//  DecisionVisitor+Switches.swift
//  SwiftCodeMetrics
//
//  The decision count's switch rules: arms, `#if` in case lists and
//  lookup-table switches (Spec §4.2).
//

import SwiftSyntax

extension DecisionVisitor {
    /// Arms counted and decisions inside a case list, choosing one clause
    /// of each `#if` by arms plus decisions.
    func summarize(_ cases: SwitchCaseListSyntax) -> CaseListSummary {
        var summary = CaseListSummary()
        for element in cases {
            switch element {
            case .switchCase(let switchCase):
                if SwitchFacts.isFallthroughOnly(switchCase) == false {
                    summary.arms += 1
                }
                let visitor = child()
                visitor.walk(switchCase)
                summary.items += visitor.items

            case .ifConfigDecl(let ifConfig):
                summary.add(bestClause(of: ifConfig))
            }
        }
        return summary
    }

    /// The clause of a case-list `#if` with the largest arms plus decisions.
    func bestClause(of ifConfig: IfConfigDeclSyntax) -> CaseListSummary {
        var best = CaseListSummary()
        for clause in ifConfig.clauses {
            guard case .switchCases(let cases)? = clause.elements else {
                continue
            }
            let candidate = summarize(cases)
            if candidate.value > best.value {
                best = candidate
            }
        }
        return best
    }

    /// A lookup table: two or more arms, each a single statement with no
    /// decisions, no `where` and no `#if` in the case list (Spec §4.2).
    func isTrivial(_ cases: SwitchCaseListSyntax, arms: Int) -> Bool {
        guard arms > 1 else {
            return false
        }
        for element in cases {
            guard case .switchCase(let switchCase) = element,
                  SwitchFacts.hasWhere(switchCase) == false,
                  switchCase.statements.count == 1,
                  let statement = switchCase.statements.first else {
                return false
            }
            let visitor = child()
            visitor.walk(statement)
            if visitor.items.isEmpty == false {
                return false
            }
        }
        return true
    }

    /// Each condition element after the first adds 1, as one item.
    func addExtraConditions(_ conditions: ConditionElementListSyntax) {
        if conditions.count > 1, let comma = conditions.first?.trailingComma {
            add(.conditionElement, amount: conditions.count - 1, anchor: comma)
        }
    }

    /// A visitor with the same settings and no items.
    func child() -> DecisionVisitor {
        DecisionVisitor(factory: factory, ignoresTrivialSwitches: ignoresTrivialSwitches)
    }

    /// Adds an item of 1.
    func add(_ rule: Increment.Rule, anchor: TokenSyntax) {
        add(rule, amount: 1, anchor: anchor)
    }

    /// Adds an item of `amount`.
    func add(_ rule: Increment.Rule, amount: Int, anchor: TokenSyntax) {
        items.append(factory.make(.decision, rule, amount: amount, anchor: anchor))
    }
}
