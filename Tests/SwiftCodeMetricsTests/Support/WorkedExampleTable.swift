//
//  WorkedExampleTable.swift
//  SwiftCodeMetricsTests
//
//  The values Spec §6 and §4.2 state, copied from the spec's text. Scores
//  read "C D SL"; each item reads "line rule amount".
//

/// The worked examples.
enum WorkedExampleTable {
    /// Every function the worked examples state values for.
    static let all: [WorkedExample] = [
        WorkedExample(
            fixture: "Example6_1.swift",
            function: "validate(_:)",
            scores: "C 6 D 6 SL 3",
            items: "2 guardStatement 1, 2 conditionList 1, 5 guardStatement 1, 5 conditionList 1, "
                + "8 guardStatement 1, 8 logicalSequence 1"
        ),
        WorkedExample(
            fixture: "Example6_4.swift",
            function: "displayName(for:)",
            scores: "C 4 D 4 SL 2",
            items: "2 ifStatement 1, 2 conditionList 1, 4 elseIf 1, 6 elseClause 1"
        ),
        WorkedExample(
            fixture: "Example6_17.swift",
            function: "firstValidToken(in:strict:)",
            scores: "C 8 D 6 SL 5",
            items: "2 loop 1, 3 guardStatement 1, 4 guardStatement 1, 5 ifStatement 3, "
                + "10 guardStatement 1, 10 logicalSequence 1"
        ),
        WorkedExample(
            fixture: "Example6_18.swift",
            function: "shouldSyncA(_:now:)",
            scores: "C 3 D 5 SL 1",
            items: "2 ifStatement 1, 2 conditionList 1, 2 logicalSequence 1"
        ),
        WorkedExample(
            fixture: "Example6_18.swift",
            function: "shouldSyncB(_:now:)",
            scores: "C 3 D 5 SL 1",
            items: "9 ifStatement 1, 9 conditionList 1, 9 logicalSequence 1"
        ),
        WorkedExample(
            fixture: "Example6_2.swift",
            function: "label(for:)",
            scores: "C 1 D 4 SL 4",
            items: "2 switchStatement 1"
        ),
        WorkedExample(
            fixture: "Example6_13.swift",
            function: "shippingCost(for:)",
            scores: "C 4 D 4 SL 4",
            items: "2 switchStatement 1, 7 ifStatement 1, 7 elseClause 1, 8 ternary 1"
        ),
        WorkedExample(
            fixture: "Example6_14.swift",
            function: "defaultLevel(verbose:)",
            scores: "C 6 D 1 SL 2",
            items: "2 conditionalCompilation 1, 3 ifStatement 2, 5 conditionalCompilationElse 1, "
                + "6 ifStatement 2"
        ),
        WorkedExample(
            fixture: "Example6_15.swift",
            function: "priority(of:)",
            scores: "C 2 D 3 SL 3",
            items: "3 switchStatement 1, 6 fallthroughJump 1"
        ),
        WorkedExample(
            fixture: "DecisionCountCheck.swift",
            function: "probe(_:)",
            scores: "C 5 D 8 SL 5",
            items: nil
        ),
        WorkedExample(
            fixture: "Example6_5.swift",
            function: "cityLabel(for:)",
            scores: "C 0 D 1 SL 0",
            items: ""
        ),
        WorkedExample(
            fixture: "Example6_6.swift",
            function: "timeout(override:environment:config:)",
            scores: "C 0 D 3 SL 0",
            items: ""
        ),
        WorkedExample(
            fixture: "Example6_7.swift",
            function: "canEdit(_:_:)",
            scores: "C 6 D 6 SL 1",
            items: "2 ifStatement 1, 4 logicalSequence 1, 4 logicalSequence 1, 5 logicalSequence 1, "
                + "5 logicalSequence 1, 5 logicalSequence 1"
        ),
        WorkedExample(
            fixture: "Example6_8.swift",
            function: "verifiedEmails(in:)",
            scores: "C 4 D 2 SL 1",
            items: "6 guardStatement 1, 7 ternary 3"
        ),
        WorkedExample(
            fixture: "Example6_9.swift",
            function: "body.get",
            scores: "C 10 D 3 SL 3",
            items: "3 ifStatement 2, 5 elseClause 1, 9 ifStatement 5, 17 ifStatement 2"
        ),
        WorkedExample(
            fixture: "Example6_12.swift",
            function: "refresh()",
            scores: "C 4 D 2 SL 2",
            items: "8 catchClause 1, 10 ifStatement 3"
        ),
        WorkedExample(
            fixture: "Example6_16.swift",
            function: "render(_:)",
            scores: "C 0 D 0 SL 0",
            items: ""
        ),
        WorkedExample(
            fixture: "Example6_16.swift",
            function: "cell(_:)",
            scores: "C 2 D 2 SL 1",
            items: "3 guardStatement 1, 4 ternary 1"
        ),
        WorkedExample(
            fixture: "Example6_3.swift",
            function: "firstMatch(in:equalTo:)",
            scores: "C 7 D 3 SL 3",
            items: "3 loop 1, 4 loop 2, 5 ifStatement 3, 7 labeledJump 1"
        ),
        WorkedExample(
            fixture: "Example6_11.swift",
            function: "loadConfig(from:attempt:)",
            scores: "C 6 D 5 SL 4",
            items: "5 catchClause 1, 7 catchClause 1, 9 catchClause 1, 10 ifStatement 2, "
                + "11 recursion 1"
        ),
        WorkedExample(
            fixture: "Example6_10.swift",
            function: "depth(of:)",
            scores: "C 2 D 1 SL 1",
            items: "2 guardStatement 1, 3 recursion 1"
        )
    ]
}
