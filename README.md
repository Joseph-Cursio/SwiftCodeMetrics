# SwiftCodeMetrics

Swift-specific complexity metrics computed from syntax alone, with no build, type checker or index store. Shared by SwiftProjectLint and SwiftStats, so both tools report the same numbers.

For every function in a file or declaration, it gives:

- **Cognitive complexity (C)**: SonarSource's specification (v1.7), extended with explicit rules for Swift constructs such as `guard`, condition lists, `if case`, `try`/`await`, result builders and `#if`.
- **Decision count (D)**: McCabe-style branch points, including `&&`, `||`, `??` and ternaries; `mccabe = D + 1`.
- **SwiftLint-compatible count (SL)**: identical to SwiftLint 0.65.1's `cyclomatic_complexity`. The test suite checks this against SwiftLint itself on about 12,500 functions.

Every score has an itemised breakdown that sums to it, with the line and column of each contributing construct.

Given every file of a module, v0.2 adds each function's coupling:

- **Fan-out**: distinct callees, keyed by receiver (`self.touch()`, `Date.init()`, `free.max(_:_:)`, `?.append(_:)`), with implicit-member calls (`.alert(...)`) and chained calls (SwiftUI modifiers) counted separately.
- **Common coupling**: the module globals, statics and singletons it reads.
- **Parameter counts**: defaulted, variadic, `inout` and closure parameters, with closures found through module typealiases.
- **Type references**: each type name in its signature and body, resolved to a module type, a platform type (standard library, Foundation, Dispatch, XCTest) or an external one.

Names are resolved by swift-syntax's lexical lookup and a symbol table that merges every type with its extensions across files.

```swift
import SwiftCodeMetrics
import SwiftParser

let tree = Parser.parse(source: source)
let analysis = SwiftCodeMetrics.functionMetrics(of: SourceFileInput(path: "File.swift", tree: tree), module: "MyModule")
for function in analysis.functions {
    print(function.key, function.complexity.cognitive, function.complexity.decisionCount)
}

// Coupling needs the whole module.
let module = SwiftCodeMetrics.analyzeModule(ModuleInput(name: "MyModule", files: inputs, isTest: false))
for function in module.functions {
    print(function.key, function.fanOut?.fanOut ?? 0, function.commonCoupling?.globals ?? [])
}
```

The definitions, worked examples, API and milestones (v0.3 adds per-type and per-module coupling and cohesion) are in [Docs/Spec.md](Docs/Spec.md). The platform table is generated from the SDK by `swift run -c release PlatformTableGenerator`.

Requires swift-syntax 603.0.2 (pinned exactly), Swift 6 language mode and macOS 14 or later.
