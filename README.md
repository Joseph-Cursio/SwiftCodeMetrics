# SwiftCodeMetrics

Swift-specific complexity metrics computed from syntax alone, with no build, type checker or index store. Shared by SwiftProjectLint and SwiftStats, so both tools report the same numbers.

For every function in a file or declaration, v0.1 gives:

- **Cognitive complexity (C)**: SonarSource's specification (v1.7), extended with explicit rules for Swift constructs such as `guard`, condition lists, `if case`, `try`/`await`, result builders and `#if`.
- **Decision count (D)**: McCabe-style branch points, including `&&`, `||`, `??` and ternaries; `mccabe = D + 1`.
- **SwiftLint-compatible count (SL)**: identical to SwiftLint 0.65.1's `cyclomatic_complexity`. The test suite checks this against SwiftLint itself on about 12,500 functions.

Every score has an itemised breakdown that sums to it, with the line and column of each contributing construct.

```swift
import SwiftCodeMetrics
import SwiftParser

let tree = Parser.parse(source: source)
let analysis = SwiftCodeMetrics.functionMetrics(of: SourceFileInput(path: "File.swift", tree: tree), module: "MyModule")
for function in analysis.functions {
    print(function.key, function.complexity.cognitive, function.complexity.decisionCount)
}
```

The definitions, worked examples, API and milestones (v0.2 adds per-function coupling, v0.3 per-type and per-module coupling and cohesion) are in [Docs/Spec.md](Docs/Spec.md).

Requires swift-syntax 603.0.2 (pinned exactly), Swift 6 language mode and macOS 14 or later.
