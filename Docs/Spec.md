# SwiftCodeMetrics: specification

Status: draft for review. Date: 2026-11-17. Depends on swift-syntax `exact: "603.0.2"`. Swift 6 language mode. macOS 14 or later. Library only.

This document merges the revised complexity draft (now Part A) and the revised coupling and cohesion draft (now Part B) into one specification. Earlier drafts called the library SwiftComplexity.

## Contents

- Decisions for review
- §1 Purpose and scope
- §2 Shared definitions
- **Part A: complexity**
  - §3 Swift cognitive complexity
  - §4 Swift decision count, and the SwiftLint-compatible count
  - §5 Result-builder hint
  - §6 Worked examples: complexity
- **Part B: coupling and cohesion**
  - §7 Shared name resolution
  - §8 v1 function-level metrics
  - §9 v1 type-level metrics
  - §10 v1 module-level metrics
  - §11 Later set and excluded metrics
  - §12 Worked examples: coupling and cohesion
- §13 Library API
- §14 Thresholds and SwiftProjectLint rules
- §15 Open questions
- §16 Implementation milestones
- §17 References
- Appendix A: SwiftLint parity probes
- Appendix B: changes from the drafts

---

## Decisions for review

Judgement calls the owner should confirm, as this specification now states them.

**Part A: complexity**
- `guard` is a flat fundamental +1, and its `else` body still nests (§3.1, §3.2 row 16, Q7).
- A condition list of two or more elements costs +1 once, whatever the order; each expression element is its own root (row 17, §3.5.2, Q8). D adds +1 per extra element (§4.2).
- `try`, `await`, `unsafe`, `consume`, `copy` and `borrow` operands, and plain parentheses, are transparent: their contents join the surrounding `&&`/`||` run (rows 48–50).
- Nested functions, local-type members and local accessors are their own records, not folded into the parent as Sonar does; the parent's SL still folds what SwiftLint folds (§2.1, §4.3).
- `resultBuilderHint` fires for `some View` and ten other builder protocols, not only `@…Builder` attributes (§5). Builder functions get cognitive threshold 30 instead of 15, to be set from SwiftStats data (§14.2, Q9).
- Thresholds: `cognitiveComplexity` > 15 (warning); `decisionCount` compared as `mccabe` = D + 1, warning > 10, error > 20 (§14.2, §14.5).
- `decisionCountIgnoresTrivialSwitches` is off by default and in SwiftStats, which stores raw D, and on in SwiftProjectLint (§4.2, §13.6, Q17).
- Recursion is direct only: an ordinary `func`, a bare, `self.` or (static only) `Self.` callee, labels fitted by the SE-0286 forward scan, parameters and locals shadowing. Other receivers give zero-amount `possibleRecursion` items (§3.4, Q10).
- `closureNesting` counts closures only, not `defer` bodies (§13.2, Q9).
- D counts `??` but not optional chaining (§4.2, Q14, Q15). `#if`: C counts every clause, D takes the maximum, SL sums (§2.6, Q2).

**Part B: coupling and cohesion**
- Lookup: bare names go through SwiftLexicalLookup's public `lookup(_:with:)`, walking every result in order; type names have no module-wide simple-name fallback, and ambiguous names never become edges (§7.2, §7.3, Q25).
- Platform modules are Swift, `_Concurrency`, `_StringProcessing`, Dispatch and Foundation, plus XCTest where imported; SwiftUI, AppKit, UIKit and Combine are not (§7.3, §7.4).
- `ceView` and `ceNamespace` are split from `ceConcrete`, beside `ceProtocol`; `ceFamily` collapses nested targets (§9.4).
- `fanOutImplicitMember` and `fanOutChained` are reported separately and left out of the headline `fanOut` (§8.1).
- LCOM4 leaves out `init`, `deinit`, statics, observers and whole-value witnesses, counts whole-`self` in structs, drops attribute-free components and adds in-module superclass attributes (§9.3, Q19–Q22, Q32).
- Singletons need a stored `static let`/`var` in a class or actor, initialised by its own type; an annotation is not enough. Outside the module, a name list (`shared`, `default`, …) decides (§8.2).
- New edge kind `constraint`; `isWeakOrUnowned` holds only if every stored-property contribution is weak or unowned (§9.4).

**Adoption and plan**
- Q1: the library renders the PRD §6.1 key. The subscript record-set difference is still open (§15.1).
- Q33: amend PRD D3 so SwiftStats links SwiftCodeMetrics, with D4 and the T1 → T0 move (Q18). Drafted in PRD v0.2.2.
- Milestones: v0.1 complexity; v0.2 per-function coupling (with extension merging); v0.3 per-type and per-module metrics; 1.0 after both adoptions (§16). The v0.2 speed target is an estimate.

---

## 1. Purpose and scope

### 1.1 Purpose

SwiftCodeMetrics is a Swift library. It computes complexity, coupling and cohesion measures for Swift source. It uses syntax only, with no type checking, no build and no index store.

It computes:

- **Per function, complexity** (Part A): cognitive complexity (C), the decision count (D, with `mccabe = D + 1`) and the SwiftLint-compatible count (SL).
- **Per function, coupling** (Part B): call fan-out, references to globals, statics and singletons, and parameter counts.
- **Per type** (Part B): sizes (NOM, NOA), WMC, LCOM4 with its member groups, outgoing type coupling (Ce and its splits) and incoming type coupling within the module (Ca).
- **Per module** (Part B): import facts, module Ce, Ca and instability, and the module's type dependency graph with its cycles.

Every value is a census value in the sense of PRD §6.4: it counts something and claims no defect. Every value comes with an itemised breakdown, so a tool can explain it line by line (§13.3).

### 1.2 Consumers

Two tools link the library, so they share one definition of every value.

- **SwiftProjectLint** (`~/xcode_projects/SwiftProjectLint`, a linter) applies thresholds and reports defects. It needs one number per function or type, compared with a threshold, plus an explanation for the report. §14 proposes the thresholds and maps its rules to library values.
- **SwiftStats** (`~/xcode_projects/SwiftStats`, a metrics store, `Docs/PRD.md`) stores every value per commit and builds signals from them. Its PRD asks for a SwiftLint-compatible cyclomatic count and for Sonar cognitive complexity ([PRD]:147-148). It lists the open Swift questions under §14 Q3 ([PRD]:494), and §3.2 answers each of them. [PRD]:147 also asks SwiftStats to record the SwiftLint version used for comparison. Its coupling and structure metrics are PRD §7.6 ([PRD]:170–177).

Because SwiftStats stores the results, every result type is `Codable` and `Sendable`. That is a design requirement of this library, not a PRD line.

Both consumers already pin swift-syntax `exact: "603.0.2"`: SwiftProjectLint at `~/xcode_projects/SwiftProjectLint/Package.swift:48` and in each of its sub-packages, SwiftStats by PRD D3 ([PRD]:485). The library's macOS 14 floor matches SwiftStats (`~/xcode_projects/SwiftStats/Package.swift:10`) and is below SwiftProjectLint's macOS 26. PRD D3 says SwiftStats links only SwiftEffectInference, so it needs amending (Q33).

The split of work: SwiftCodeMetrics owns the count, SwiftProjectLint owns whether it is a defect (§14.4), and SwiftStats owns storage, trends and joins.

### 1.3 What the library does not do

The library reads source as written. Anything that needs types, a build, the index store or git history stays in SwiftStats' collectors.

| Quantity | Why syntax cannot do it | Owner |
|---|---|---|
| Exact fan-in to a function or type | It needs every caller, with overloads and dispatch resolved | SwiftStats indexstore-db collector (PRD §7.6, M7) |
| Cross-module type references | Syntax cannot tell which imported module supplies a name | indexstore-db collector (M7) |
| Exact type-level cycles | Name collisions and inferred types make syntactic edges approximate | indexstore-db collector (M7) |
| Change coupling | It comes from git history | SwiftStats history collector (PRD §7.13, M3) |
| Hidden coupling (change coupling with no static dependency) | It joins git pairs with static edges | SwiftStats (PRD §8, M7); it can use the library's syntactic edges as an approximation before M7 |

The library defines the shared record shapes (§13) so that the index collector writes the same records with a different provenance. The library never stores, trends or joins data. That is SwiftStats' job.

**PRD change this implies.** PRD §7.6 ([PRD]:170–177) places LCOM and module coupling at T1. Both can move to T0. A type's accesses to its own members resolve lexically, and module edges come from `import` declarations. Exact fan-in, cross-module references and exact type cycles stay at T1. See Q18.

Also out of scope:

- Type checking and semantic resolution. User overloads of `&&` cannot be detected. Nor can result-builder trailing closures, recursion through another instance, or overloads that share a base name and argument labels (§3.4). Part B resolves names lexically for the same reason (§7).
- Macro expansion. Only the source as written is analysed, macro arguments included (§2.7).
- Indirect recursion (a call graph across functions).
- Picking the active `#if` clause from a build configuration. No build configuration is applied (§2.6). A later option could use `SwiftIfConfig`'s `ConfiguredRegions` (`Sources/SwiftIfConfig/ConfiguredRegions.swift:97`), which lexical lookup already accepts (`LookupConfig.configuredRegions`, `SLL/LookupConfig.swift:36`) and which the product links from v0.2 anyway (next item). See Q2.
- Aggregating complexity per file or module. Per-type WMC (§9.2) is the only complexity aggregate the library computes, from the per-function records.
- Thresholds, severities and report wording. Consumers do that, though §14 recommends values.
- NPath, Halstead and nesting-depth metrics. `maxNesting` (§13.2) is reported as a fact, not a metric with a threshold.
- Parsing and directory walking. Consumers parse and pass syntax trees in, with an explicit file list per module (§1.4). The library's code imports `SwiftSyntax`, and from v0.2 also `SwiftLexicalLookup` (Q25). It never calls `SwiftParser` (consumers parse) or `SwiftOperators` (folding is not required, §3.5.1). From v0.2 the product links both anyway, indirectly: `SwiftLexicalLookup` depends on `SwiftIfConfig` (`Package.swift:205–206` in the checkout), which depends on `SwiftSyntaxBuilder`, `SwiftDiagnostics`, `SwiftOperators` and `SwiftParser` (`Package.swift:169–170`). v0.1 links `SwiftSyntax` alone. Tests and the platform-table generator (§7.4) call `SwiftParser` directly.
- Closures in default parameter values (§2.1). Top-level code is scored only by the file walker (Q6).

### 1.4 Inputs

- **Function level.** The caller passes one declaration, or one parsed file (§13.1). No module context is needed. Complexity is final at this level.
- **Type and module level.** The caller passes an explicit list of files for each module, and says whether the module is a test target. The library does not walk directories. In the prototype, directory walking picked up TCA's `Documentation.docc` tutorial snippets, which declare `ContactsFeature` in 43 files under `Sources/` (49 counting extensions). They merged into one nonsense type (example file: `~/GitHub_projects/swift-composable-architecture/Sources/ComposableArchitecture/Documentation.docc/Tutorials/MeetTheComposableArchitecture/02-Navigation/01-YourFirstPresentation/02-01-02-code-0001.swift`). SwiftStats' target resolution already produces the right file lists.
- Callers pass trees parsed with swift-syntax 603.0.2. Unfolded trees are the normal case. Folded trees are accepted too (§3.5.1).

### 1.5 Conventions

**Citations.** Citations use the short labels defined in §17. A path is in the swift-syntax 603.0.2 checkout at `~/xcode_projects/SwiftStats/.build/checkouts/swift-syntax` unless it starts with `~` or with one of the prefixes below. That checkout is HEAD `79e4b74a2`, tagged `603.0.2`, and matches `~/xcode_projects/SwiftStats/Package.resolved:18-19`. Parse shapes quoted below were checked with a parse-tree dumper built against that checkout.

Path prefixes:

- `N/` = `Sources/SwiftSyntax/generated/syntaxNodes/` in that checkout. The coupling draft wrote `SS/` for the same directory.
- `P/` = `Sources/SwiftParser/` in that checkout.
- `SLL/` = `Sources/SwiftLexicalLookup/` in that checkout.
- `SPL/` = `~/xcode_projects/SwiftProjectLint/Packages/SwiftProjectLintRules/Sources/SwiftProjectLintRules/`.
- `SDK/` = `$(xcrun --show-sdk-path)` (SDK 27.2).
- `[PRD]` = `~/xcode_projects/SwiftStats/Docs/PRD.md`. `[PRD]:147` is a line of it; "PRD §7.6" is a section of it. Other `§` numbers refer to this document.

**Terms.**

- A **function** is one function record (§2.1). `func` in code font means the declaration kind only.
- A **type** is a struct, class, enum, actor or protocol declaration with its merged extensions (§2.2). A **member** is a declaration in a type that NOM counts (§2.3); one member can own several functions, for example a computed property with a getter and a setter.
- Older drafts used "unit" for a scored body and also for a type. This document does not use that word.
- "Sonar's specification" means [CC]. "This specification" means this document.
- **C** is cognitive complexity, **D** the decision count and **SL** the SwiftLint-compatible count (Part A).

---

## 2. Shared definitions

Both parts use these definitions. Part A and Part B refer here and do not restate them. Where a metric uses a narrower set, its section says so.

### 2.1 Function

A **function** is one scored body. The function kinds are:

| Function kind | Syntax | Body |
|---|---|---|
| `func` | `FunctionDeclSyntax` with `body != nil` (`N/SyntaxNodesEF.swift:3323`) | `CodeBlockSyntax` |
| `init` | `InitializerDeclSyntax` with a body (`N/SyntaxNodesGHI.swift:4061`) | `CodeBlockSyntax` |
| `deinit` | `DeinitializerDeclSyntax` with a body (`N/SyntaxNodesD.swift:927`) | `CodeBlockSyntax` |
| `subscript`, implicit getter | `SubscriptDeclSyntax.accessorBlock` whose `accessors` is `.getter` (`N/SyntaxNodesQRS.swift:3196`, `N/SyntaxNodesAB.swift:596`) | `CodeBlockItemListSyntax` |
| computed property, implicit getter | `PatternBindingSyntax.accessorBlock` whose `accessors` is `.getter` (`N/SyntaxNodesOP.swift:1658`) | `CodeBlockItemListSyntax` |
| explicit accessor | each `AccessorDeclSyntax` with a body (`N/SyntaxNodesAB.swift:836`), in a property or a subscript. Every `accessorSpecifier` value counts: `get`, `set`, `willSet`, `didSet`, `init`, `_read`, `read`, `_modify`, `modify`, `unsafeAddress`, `unsafeMutableAddress`, `borrow`, `mutate`, and the four owner variants `addressWithOwner`, `addressWithNativeOwner`, `mutableAddressWithOwner` and `mutableAddressWithNativeOwner`: all 17 specifiers in the doc comment at `N/SyntaxNodesAB.swift:828` | `CodeBlockSyntax` |
| nested function | a `FunctionDeclSyntax` in another function's body | its own function, with a link to the parent |
| local computed or observed variable | a `var` with an accessor block declared in a function's body, such as `var x: Int { … }` or `var y = 0 { didSet { … } }` | its own function(s), by the getter and accessor rows above, with a link to the parent |
| local type members | members of a `struct`, `class`, `enum` or `actor` declared in a function's body, including members inside a `#if` in its member list | their own functions, with a link to the enclosing function |
| stored-property initial value | the initialiser expression of a stored property of a type (instance or `static`, in a top-level or local type), or of a global (file-scope) variable, when its C or D would be non-zero (Q6) | its own function of kind `.propertyInitializer`, linked to the enclosing function if the type is local, with no parent otherwise |
| top-level code | the file's top-level statements: items of `SourceFileSyntax.statements` that are statements or expressions, not declarations. Only for a file that has at least one; file walker only (Q6) | one function of kind `.topLevelCode` per such file, with no parent |

Rules:

- **Closures fold into the nearest enclosing function.** This matches Sonar's specification [CC p.9], Sonar Java ([Java] L273–277) and SwiftLint (a probe gave 1 for `xs.forEach { if … }`). It also matches the SwiftStats record rules ([PRD]:70-71).
- **Nested functions, local computed and observed variables, and local-type members are excluded from the parent's C and D.** This is a deliberate deviation from Sonar's specification, which folds nested methods into the parent with a nesting increment [CC p.9]. Precedents for scoring them separately: SonarJS reports each nested function on its own ([JS] rule.ts L204–230), and sonar-dotnet scores static local functions on their own ([CSharp-tests] Latest.cs L212–225). The reason is that both consumers want one record per function, and the PRD already models nested functions as their own records ([PRD]:70). A local accessor is a body like any other, so it is treated the same way.
- **The parent's SL still includes the bodies SwiftLint folds in.** Those are every local body except nested `func` and `init` (§4.3). This keeps SL exact.
- **A local variable's initial value is part of the parent's body.** `let y = { … }()` is an ordinary closure in the body, and the `0` in `var y = 0 { didSet … }` runs in the body.
- **Default argument values are not scored anywhere.** SwiftLint ignores them too (probe: a closure in a nested function's default value added nothing to either function).
- A nested function starts at nesting level 0 (§3.3).
- Protocol requirements and accessor declarations without bodies are not functions.
- **Every `func` and `init` with a body is a record**, wherever it is declared. That includes one inside a closure in a stored-property or global initial value that has no record of its own (its C and D are 0), one inside a default-argument closure, and one inside a top-level or global-variable closure. Its parent is the nearest enclosing record, or none. Why: SwiftLint scores every `func` and `init` with a body ([CCR]:78-94), and the parity test (§16) needs a record for each.
- **Globals and statics.** A global variable's initial value, and a `static` stored property's, are treated like an instance stored property's: a `.propertyInitializer` record when C or D is non-zero, and nothing otherwise. Syntax cannot tell a `main.swift` top-level `let` from a global declaration, so every top-level variable declaration is a global, never top-level code.
- **Order.** Records are listed pre-order depth-first by start UTF-8 offset, as defined once in §13.1.

**Records and keys.**

- Each function is one record (§13.2). Its key is the PRD §6.1 syntactic key ([PRD]:53): module, enclosing path (for a nested function, its parent record's key), declaration kind, `static`/`class`, operator fixity, name, generic signature, parameter labels and types, effects, return type and `#if` condition. The file path is added only for `private` and `fileprivate` declarations. The API calls this key `MemberKey` (§13.2). Who renders it is Q1.
- A function declared in two `#if` clauses is two records, because the `#if` condition is part of the key (§2.6).
- Each record also has a readable name, such as `loadConfig(from:attempt:)`, `subscript(_:).get` or `body.get`, and a link to its parent record for nested and local functions.

**Mapping to SwiftStats' kinds.** SwiftStats keeps its own `FunctionKind` (`~/xcode_projects/SwiftStats/Sources/SwiftStatsCore/Model/FunctionKind.swift:12–26`), which follows PRD §6.1a ([PRD]:66–75). The library's kinds (§13.2) map onto it as follows.

| Library kind | SwiftStats kind | Note |
|---|---|---|
| `.function` | `func` | includes nested and operator functions |
| `.initializer` | `init` | |
| `.deinitializer` | `deinit` | |
| `.subscriptGetter` | `subscript` | a subscript with an implicit getter |
| `.computedGetter` | `accessor` | the implicit getter of a computed property or local variable |
| `.accessor` | `accessor` | every explicit accessor, in a property or a subscript |
| `.propertyInitializer` | none | PRD §6.1 attaches results outside a function body to the enclosing type or file ([PRD]:64) |
| `.topLevelCode` | `topLevel` | at most one per file, only for a file with top-level statements; file walker only |

SwiftStats' collector also emits a `subscript` record for a subscript with explicit accessors, around its accessor records (`~/xcode_projects/SwiftStats/Sources/SwiftStatsCore/Functions/FunctionCollector.swift:238–254`). The library has no record for that declaration; its accessors are the records (Q1).

**Nested functions.** PRD §6.1a makes a nested function its own record, linked to its parent. Each metric treats it as follows:

| Metric | Nested function |
|---|---|
| Fan-out, common coupling, parameter counts (§8) | Its own function. Its calls and references are not counted in the parent. |
| WMC (§9.2) | Its own term in the sum. |
| LCOM4 accesses and calls (§9.3) | Walked as part of the member that contains it. It is not a node. |
| Ce (§9.4) | Its type names count for the enclosing type, like any body. |

Why: per-function values follow the PRD records, but a nested function only runs through its parent, so cohesion treats it as the parent's code.

Local computed and observed variables in a function body are treated like nested functions by every Part B metric. Why: Part A already makes them their own records, for the same reason.

**Stored-property initial values in Part B.** A `.propertyInitializer` record carries complexity only. Its type names count towards its type's Ce (§9.4). Part B computes no function-level coupling for it (§8), and it is not a WMC term (§9.2). Why: the record exists only when C or D is non-zero, so coupling values on it would appear and vanish with an unrelated score; the type is the owner the PRD names ([PRD]:64). A global variable's `.propertyInitializer` record belongs to no type, so its type names count towards no type's Ce.

**Top-level code in Part B.** A `.topLevelCode` record gets function-level coupling like any function. It belongs to no type.

### 2.2 Type

- A type is a `struct`, `class`, `enum`, `actor` or `protocol` declaration:
  - `StructDeclSyntax` (N/SyntaxNodesQRS.swift:2556)
  - `ClassDeclSyntax` (N/SyntaxNodesC.swift:765)
  - `EnumDeclSyntax` (N/SyntaxNodesEF.swift:1268)
  - `ActorDeclSyntax` (N/SyntaxNodesAB.swift:1387)
  - `ProtocolDeclSyntax` (N/SyntaxNodesOP.swift:4322)
- Each of them is read through `.name`, `.modifiers`, `.attributes`, `.inheritanceClause?.inheritedTypes` (each an `InheritedTypeSyntax` with `.type`, N/SyntaxNodesGHI.swift:3795) and `.memberBlock.members` (each a `MemberBlockItemSyntax` with `.decl`, N/SyntaxNodesJKLMN.swift:3960). All except protocols also have `.genericParameterClause`. Protocols have `.primaryAssociatedTypeClause` instead.
- **Key.** A type's `TypeKey` is the module plus the nominal path, with generic arguments stripped (`Shop.Inventory`, `HeapModule.Heap._UnsafeHandle`). The file path is added only when the type is `private` or `fileprivate`. This is the type part of the PRD §6.1 key ([PRD]:49–55), without the extension `where` clause.
- **Local types.** A type declared inside a function body is keyed by that function's PRD §6.1 key plus its name. It is measured like any type. It belongs to the nesting family of the type that contains the function (see "Nesting family" below). Why: Swift scopes it to the function, and the function key is already unique in the module.
- **Extensions merge into their type across all files of one module.** An `ExtensionDeclSyntax` (N/SyntaxNodesEF.swift:2039) is read through `.extendedType`, `.inheritanceClause`, `.genericWhereClause` and `.memberBlock`.
  - Resolve `.extendedType` to a type: `IdentifierTypeSyntax` (`Foo`), `MemberTypeSyntax` (`Outer.Inner`), generic arguments stripped (`Array<Int>` becomes `Array`), sugar mapped (`[Int]` becomes `Array`, `Int?` becomes `Optional`), and module typealiases expanded (§7.3).
  - Constrained extensions (`extension Foo where T: Hashable`) merge too. Each member keeps its `where` clause in its own key, as PRD §6.1 requires.
  - **Why merge:** the prototype found about 48% of swift-collections' extensions in a different file from their type (23% in GRDB, 20% in TCA, 11% in swift-nio). `BitSet` is declared at `~/GitHub_projects/swift-collections/Sources/BitCollections/BitSet/BitSet.swift:28` and extended from 32 other files. Measured one extension at a time, every type would look small and cohesive.
- **Extension groups.** An extension whose extended type has no module declaration at any level (`extension Array`, `extension String`) forms an *extension group* keyed by the extended name. It has members but no stored state. Its cohesion is null. It has outgoing coupling.
- **Unresolved extensions.** An extension of `A.B` where `A` resolves to a module type but `B` is not among A's nested types is not an extension group. Example: `extension SyncUpDetail.Destination.State: Equatable {}` (swift-composable-architecture/Examples/SyncUps/SyncUps/SyncUpDetail.swift:118), where `State` is generated by `@Reducer`. It is listed in the module's `unresolvedExtensions`. Its functions still get records, but it is not merged and forms no type. Why: the extended type is in the module but invisible, so an extension group would claim a type outside the module.
- **Nested types are separate types.** A nested `Iterator` is not a member of `BitSet`. Its body is excluded from the outer type's metrics.
- **Nesting family.** A type's nesting family is its outermost enclosing type and every type nested in that, at any depth, including local types. References inside one family are `internalRefs`, never Ce edges, in either direction (§9.4).

### 2.3 Member ("method")

- **For NOM:** a member is a `func` (`FunctionDeclSyntax`, N/SyntaxNodesEF.swift:3323), `init` (`InitializerDeclSyntax`, N/SyntaxNodesGHI.swift:4061), `deinit`, `subscript` (`SubscriptDeclSyntax`, N/SyntaxNodesQRS.swift:3196) or computed property declared in the type or its merged extensions.
  - A computed property counts once, whatever accessors it has.
  - Static and class members count. §9.1 says how NOM is broken down.
  - Stored properties, enum cases, typealiases, associated types and nested types are not members.
  - Nested functions are not members. They are their own functions (below).
  - Protocol NOM is defined in §9.1.
- **For WMC:** sum over the PRD §6.1a function records ([PRD]:66–75): `func`, `init`, `deinit`, `subscript`, every explicit accessor including `willSet`/`didSet` and computed-property bodies, and nested functions. This is SwiftStats' `FunctionKind` set (`~/xcode_projects/SwiftStats/Sources/SwiftStatsCore/Model/FunctionKind.swift:12–26`). Closures fold into their enclosing function. In library terms that is every kind except `.propertyInitializer` and `.topLevelCode` (§2.1).
- **For the cohesion graph:** a narrower set, M, defined in §9.3.

### 2.4 Stored property ("attribute")

- A stored instance property is a binding in a `VariableDeclSyntax` (N/SyntaxNodesTUVWXYZ.swift:3503) in the type's primary `memberBlock` that meets both of these conditions:
  - `.modifiers` has no `static` or `class` (`DeclModifierSyntax.name`);
  - its `PatternBindingSyntax` (N/SyntaxNodesOP.swift:1658) has `.accessorBlock == nil`, or an `.accessorBlock.accessors` of case `.accessors(AccessorDeclListSyntax)` whose accessors are all `willSet` or `didSet` (`AccessorDeclSyntax.accessorSpecifier`).
- This includes `let`, `var`, `lazy var`, observed, property-wrapped, `weak` and `unowned` properties, and stored closures. A tuple pattern gives one attribute per identifier.
- Swift extensions cannot add stored properties [Swift-Ext]. So the attribute set is complete once the primary declaration is read. Macro-added storage is the exception.
- Enum associated values are not attributes. Enums therefore have no attributes.
- Static stored properties are not attributes. They are shared state, which is common coupling (§8.2).
- NOA counts a type's own stored instance properties. The cohesion attribute set A (§9.3) adds those of the in-module superclass chain.

### 2.5 Module

- A module is one compiled target, as the caller defines it by the file list it passes (§1.4). Its name is the Swift module name that `import` declarations use.
- Each module says whether it is a test target. Test modules are measured like any other module. They are left out of module `ca` and counted in `caTests` (§10.2).
- Extensions merge into their type within one module only (§2.2). The module's types, globals, free functions and typealiases form its symbol table (§7.1).
- A **scan** is the set of modules passed to the package pass (§13.1). "Scanned modules" in §10 are its modules. Platform modules are defined in §7.4.

### 2.6 `#if`

Every metric walks every clause, as PRD §6.1a does ([PRD]:73). No build configuration is applied (§1.3). Each metric then combines clauses as follows.

| Metric | How clauses combine | Where |
|---|---|---|
| C | every clause counts; `#if` is structural, `#elseif` and `#else` are hybrid | §3.2 rows 59–61 |
| D | the maximum over clauses, recursively | §4.2 |
| SL | all clauses summed, as SwiftLint does | §4.3 |
| Part B function and type metrics | the union of calls, accesses and edges | below |
| WMC | the larger value per member | §9.2 |
| Import facts | each import keeps its enclosing condition | §10.1 |

Why they differ: C measures reading, and the reader reads every clause. D counts paths, and one build runs one clause. SL copies SwiftLint. Part B describes the design as written in every configuration.

- **Function records.** A function declared in two clauses is two records with different keys (§2.1).
- **Type metrics.** `IfConfigDeclSyntax.clauses` → `IfConfigClauseSyntax.condition`, `.elements` (case `.decls(MemberBlockItemListSyntax)`) (N/SyntaxNodesGHI.swift:2198, :1867). Members whose keys differ only in their `#if` condition are one member for the type metrics, with the union of their accesses and edges.
- **Placement.** A `#if` in a member list is outside every function body. A `#if` in an attribute list can sit inside a body, on a closure or a local declaration, but it selects attributes, not run-time code. Part A scores neither, wherever it appears (§3.3). Part B still reads the members in every clause.
- **Conditions.** Operators in a `#if` condition are build settings, not run-time logic. No metric counts them (§3.2 row 61; §3.5.3).

### 2.7 Macros

The library measures source as written. Expanding macros needs built plugins, which breaks the syntax-only rule.

- **Freestanding macros** (`#expect(a && b)`, `#Predicate { … }`). The macro itself adds nothing: no cognitive increment and no decision (§3.2 row 62; §4.2), and no fan-out key. Part B counts it in `macroExpansionCount` instead (§8.1). Its arguments are ordinary source, and every metric walks them as written. Closures in its arguments fold into the enclosing function and nest (§3.2 row 4). Calls in its arguments count towards fan-out, and type names in them towards Ce. Why: the reader reads the arguments, and the expansion is invisible to syntax.
- **Attached macros and `macro` declarations** add no visible control flow (§3.2 row 63). Members, storage and conformances added by attached macros [SE-0389] are invisible. The library records the custom attributes on each type and sets `hasKnownAttachedMacro` (§9.1).
- Results inside a macro expansion cannot be mapped to a record. PRD §6.1a reports them as unmapped ([PRD]:66–75).

### 2.8 Walking and broken source

- Walk with `viewMode: .sourceAccurate`, and skip the children of `UnexpectedNodesSyntax`. A function whose range contains unexpected or missing nodes gets `hasSyntaxErrors = true`. This applies to every metric in both parts (Q5).

---

# Part A: complexity

Part A defines three per-function scores. What a function is, and how closures, nested functions, `#if` and macros are treated, is in §2.

- **Cognitive complexity (C).** This follows SonarSource's Cognitive Complexity specification, v1.7 [CC]. §3 adds explicit rules for the Swift constructs Sonar's specification does not cover.
- **Decision count (D).** This counts the run-time branch points in Swift. It is a McCabe-style measure, with base 0. It is deliberately not called "cyclomatic complexity", so that it is not confused with SwiftLint's rule. The library also exposes `mccabe = D + 1`.
- **SwiftLint-compatible count (SL).** This reproduces SwiftLint's `cyclomatic_complexity` exactly, so tools can match SwiftLint numbers ([CCR]; §4.3).

Every score comes with an itemised breakdown (§13.3).

Sonar has published no Swift-specific rules. Its old Swift analyser was closed source. On SonarQube Cloud, `swift:S3776` now has status REMOVED [S3776-API]. The new compiler-based analyser [Forum-172187] does not yet include cognitive complexity ([Forum-179778]; [Forum-183000]). The last archived Swift rule page has only generic text [S3776-archive]. So no rule below can "follow Sonar's Swift choice": there is none. Each Swift rule is justified from Sonar's specification, or from Sonar's implementations for other languages.

"The first draft" in Part A means the first draft of the complexity rules, written before the merge. Its rules are kept in some tables and examples for comparison (Appendix B).

## 3. Swift cognitive complexity

### 3.1 Sonar's increment kinds

Sonar's specification has three increment kinds, plus a separate nesting increment [CC p.5]:

- **Structural.** +1, plus a nesting increment equal to the current nesting level. Raises the nesting level for its body. Examples: `if`, ternary, `switch`, loops, `catch`, `#if` [CC p.6, Appendix B p.16].
- **Hybrid.** +1, with no nesting increment. Raises the nesting level. Examples: `else if` and `else` [CC p.6].
- **Fundamental.** +1 flat. No nesting increment, and no effect on nesting. Examples: logical-operator sequences, recursion, and labelled or multi-level jumps [CC pp.7–8, B1]. Exception: `guard` is fundamental, but its `else` body raises the level (row 16).
- Lambdas and nested methods raise nesting with no increment of their own [CC p.9, B2].

Every increment adds 1 whatever its kind. The kind says only where nesting applies [CC p.6].

**Sonar rules kept as they are:**

1. No cost for entering a function [CC p.6, p.11].
2. Structural +1 plus nesting for `if`, ternary, `switch`, loops and `catch` [CC B1–B3].
3. Hybrid +1 for `else if` and `else` [CC p.6].
4. One increment for a whole `switch`, however many cases it has [CC p.7].
5. Each `catch` is +1. `try` and the `do` block add nothing and do not nest [CC p.7].
6. One fundamental increment per run of like binary logical operators, in source order [CC pp.7–8].
7. Labelled `break` and `continue` are +1 fundamental. Unlabelled jumps and early returns are free [CC p.8].
8. Null-coalescing and null-conditional access are ignored [CC p.6]. Every Sonar implementation ignores both `?.` and `??` (C#: [CSharp-tests] CognitiveComplexity.cs L193–212; Kotlin: [Kotlin] L166–167; JS: [JS] L378–382).
9. Closures add no increment, raise nesting by 1 and fold into the enclosing function [CC p.9].
10. `#if` is a structural conditional [CC p.6, p.9].

**Deviations from Sonar's specification:**

- Nested functions and local-type members are scored separately (§2.1).
- Recursion is detected for direct recursion only. Sonar's specification counts every method in a cycle [CC p.8]. Only sonar-dotnet implements recursion at all, and only direct recursion ([CSharp] L103–113, L176–187).

**Swift additions:**

- `guard`, as a fundamental increment (row 16)
- condition lists, as one increment per list (row 17)
- `fallthrough`
- `defer`
- `where` clauses
- `#elseif` / `#else`
- operator-sequence identification on unfolded trees, including `try`, `await`, `unsafe`, `consume`, `copy` and `borrow` operands

These are defined in the table and in §3.3–§3.5.

### 3.2 Construct table

Key:
- **Incr.**: increment kind.
- **Nest. incr.**: whether the construct receives a nesting increment.
- **Raises**: whether it raises the nesting level for the code it contains.

"`where`" in this table always means `WhereClauseSyntax` (`N/SyntaxNodesTUVWXYZ.swift:4070`) on a case item, a `for` or a catch item. It never means `GenericWhereClauseSyntax` (`N/SyntaxNodesGHI.swift:1270`) on a declaration, which costs nothing.

| # | Construct | Incr. | Nest. incr. | Raises | Sonar precedent | Rationale |
|---|---|---|---|---|---|---|
| 1 | The function itself (`func`, `init`, `deinit`, `subscript`, accessor, implicit getter) | none | no | no (body starts at 0) | [CC p.6, p.11] | No cost of entry. |
| 2 | Nested `func` in a function | none in parent | no | own function, starts at 0 | Deviation from [CC p.9]. Like [JS] L204–230 and C# static local functions ([CSharp-tests] Latest.cs L212–225) | One record per function. A nested function reads as a function. |
| 3 | Members of a local type; local computed or observed variables | none in parent | no | own functions, start at 0 | Deviation from [Java] L133–143 (local-class methods fold) | Same as row 2. |
| 4 | Closure, in any position: argument, trailing, multiple trailing, string interpolation, macro argument | none | no | yes | [CC p.9, B2]; [Java] L273–277; [Kotlin] L132–135; [Rust] L135–137 | The code runs elsewhere or later. The reader holds an extra context. |
| 5 | `Task {}`, `Task.detached {}`, task-group `addTask {}` | none | no | yes (closure rule) | as row 4 | Concurrency is not a branch. The closure is an ordinary closure. |
| 6 | `async let x = expr` | none | no | no | none | No branch. The initialiser is an expression in syntax, not a closure. |
| 7 | `await`, `for try await`, `try await` keywords | none | no | no | none | Suspension is not a branch. |
| 8 | `defer { }` | none | no | yes | Go: `defer` itself costs 0, but a deferred function literal nests ([Go-tests] L109–110, L264–267) | The body runs out of source order, at every exit. That is the lambda situation of [CC B2]. |
| 9 | Result-builder body (`@ViewBuilder` etc., or a `some View` result) | none | no | no | Kotlin counts `@Composable` normally and raises only the threshold, to 45 ([Kotlin-check] L31–32, L42) | Builder `if`, `switch` and `for` are real run-time branches (`buildEither` / `buildOptional`). Handle builders with a threshold (§14.2), not a special count. |
| 10 | Builder container closures (`VStack { }`, `List { }`) | none | no | yes (closure rule) | as row 4 | Syntax cannot tell a builder closure from any other without types. See Q9. |
| 11 | `forEach`, `map`, `filter`, SwiftUI `ForEach` | none for the call | no | yes (closure rule) | as row 4 | These are calls, not loops in syntax. |
| 12 | `if` statement | structural | yes | yes | [CC B1–B3] | Kept as Sonar. |
| 13 | `if` expression ([SE-0380]), e.g. `let v = if c { 1 } else { 2 }` | as `if`/`else` statements | yes | yes | Kotlin makes `else` free when its branch is a bare expression ([Kotlin] L159–162) | Same node, `IfExprSyntax`, in both positions (`P/Statements.swift:82-97`; `P/Expressions.swift:604-610`). Refactoring between the statement and expression forms should not change the score. See Q13. |
| 14 | `else if` | hybrid | no | yes | [CC p.6]; [Java] L175–183 | Kept as Sonar. Recognised as an `IfExprSyntax` that is its parent `IfExprSyntax`'s `elseBody` (`N/SyntaxNodesGHI.swift:2349`). The chain is flat (§3.3). |
| 15 | `else` of an `if` | hybrid | no | yes | [CC p.6] | Kept as Sonar. A `guard`'s `else` is not this row (row 16). |
| 16 | `guard … else { }` | fundamental | no | yes, for its `else` body only. Code after the `guard` is not nested. | Counter-precedents: Kotlin `x ?: return` costs 0 ([Kotlin] L166–167); Go exempts `if err != nil` guards using type information ([Go] L100–103, L183–216) | A guard reads flat at any depth. `guard … else { continue }` in a loop is a filter, and the equivalent `for … where` is free (row 31). The calibration found nested guards were the main inflator (14 of 23 points in one parser). The `guard` itself costs, because each one is a rejection rule the reader must hold. Q7. |
| 17 | Condition list with two or more elements, in an `if`, `guard` or `while` | fundamental, +1 once per list | no | no | By analogy with one `&&` run [CC pp.7–8] | Conditions are evaluated left to right and stop at the first failure [SE-0099], so a list is one chain of checks. One increment per list makes the score independent of element order. Each `.expression` element is its own root sequence (§3.5). Q8. |
| 18 | Optional binding: `if let`, `guard let`, `while let`, `if let x` shorthand | none (part of its statement) | no | no | Rust `if let` scores exactly like `if` ([Rust] L77–104, inferred) | A binding is a condition, already paid for by the `if` / `guard` / `while`. |
| 19 | `if case`, `guard case`, `while case` pattern | none | no | no | Rust `if let`; C# property patterns cost 0 ([CSharp-tests] Latest.cs L80–117) | One pattern test is one condition, already paid for. |
| 20 | `#available` / `#unavailable` condition | none (an element; row 17 applies to the list) | no | no | none | A run-time OS check, paid for by its statement. |
| 21 | `switch` (statement or expression) | structural | yes | yes (case bodies) | [CC p.7]; Kotlin `when` ([Kotlin] L67); Rust `match` ([Rust] L95–104) | Kept as Sonar. |
| 22 | `case`, `default`, `@unknown default` | none | no | no | [CC p.7] | Covered by the `switch` increment. |
| 23 | Multi-pattern case `case .a, .b:` | none | no | no | [CC p.7]. C# counts `or` pattern combinators ([CSharp] L64–83); not followed | A case's patterns are a list of labels, not a boolean expression. |
| 24 | `where` on a case item | none. Logical operators inside it count by row 49. | no | no | none | It is part of the case's pattern match, which the single `switch` increment covers. |
| 25 | Any `fallthrough` that is not its case's only statement: after other statements, nested in an `if` in the case body, or first but not alone | fundamental | no | no | `goto` is fundamental [CC p.8, B1]. C# counts `goto case` ([CSharp-tests] L676–700) | A jump into the next case's body. The reader must keep reading past the case boundary. |
| 26 | `fallthrough` as the only statement in its case | none | no | no | [CC p.7] | Equivalent to a multi-pattern case (`case 0: fallthrough; case 1:` means `case 0, 1:`). |
| 27 | Ternary `c ? a : b` | structural | yes | yes (both branches) | [CC B1–B3] | Kept as Sonar. |
| 28 | Chained ternary `a ? b : c ? d : e` | structural each, inner one nested | yes | yes | [CC B3]; [Java] L234–239 raises nesting for the whole conditional expression | The inner ternary sits in the outer one's else branch (§3.5.4). |
| 29 | `for-in`, including `for try await` | structural | yes | yes | [CC B1–B3] | Kept as Sonar. |
| 30 | `for case <pattern> in` | none extra | no | no | as row 19 | A pattern, not an extra structure. |
| 31 | `for … where c` | none extra. Logical operators inside count. | no | no | Rule 1 of [CC p.5]: ignore shorthand that makes code more readable | It replaces an `if` and a level of nesting. Free, like row 24. |
| 32 | `while` | structural | yes | yes | [CC B1–B3] | Kept as Sonar. |
| 33 | `repeat { } while c` | structural | yes | yes | do-while [CC B1–B3] | Kept as Sonar. |
| 34 | `repeat each` pack expansion | none | no | no | none | Not a loop (`PackExpansionExprSyntax`, `N/SyntaxNodesOP.swift:1415`). Only `repeat {` starts a loop. |
| 35 | `do { }`, `do throws(E) { }`, and `DoExprSyntax` (experimental, gated on `.doExpressions` at `P/TokenSpecSet.swift:749` and `P/Statements.swift:71`) | none | no | no | [CC p.7]; [Java] L191–198 | Kept as Sonar: `try` blocks are ignored. |
| 36 | `catch` clause | structural | yes | yes | [CC p.7, B1–B3] | Kept as Sonar. |
| 37 | `catch A, B` (several items) | none extra | no | no | [CC p.7]: one increment however many types | Kept as Sonar. |
| 38 | `catch … where c` | none extra. Logical operators inside count. | no | no | as row 24 | Same reasoning as row 24. |
| 39 | `try` | none | no | no | [CC p.7] | Kept as Sonar. |
| 40 | `try?` | none | no | no | Nearest analogues are `?.` and `??`, ignored by [CC p.6] and every implementation | Shorthand that turns an error into `nil`. The test that later consumes the `nil` is counted where it occurs. |
| 41 | `try!` | none | no | no | none | A trap, not a branch the reader follows. |
| 42 | `throw` | none | no | no | [CC p.8]: only labelled or multi-level jumps count | An exit. The condition leading to it is already counted. |
| 43 | `return`, early or not | none | no | no | [CC p.8] | Kept as Sonar. |
| 44 | Unlabelled `break` / `continue` | none | no | no | [CC p.8] | Kept as Sonar. |
| 45 | Labelled `break label` / `continue label` | fundamental | no | no | [CC p.8, B1]; [Java] L250–262; [Kotlin] L68–69; [Go] L94–98; [Rust] L105–112 | Kept as Sonar. Recognised by `label != nil` (`N/SyntaxNodesAB.swift:5489`, `N/SyntaxNodesC.swift:4274`). |
| 46 | Statement label `outer:` (`LabeledStmtSyntax`) | none | no | no | none | Only the jump costs. |
| 47 | `yield` | none | no | no | none | Not a branch. |
| 48 | `discard self`, `consume`, `copy`, `borrow` (also spelled `_borrow` under the experimental `oldOwnershipOperatorSpellings`, `N/SyntaxNodesAB.swift:5368`, `P/TokenSpecSet.swift:712`), `unsafe` | none | no | no | none | Not a branch. Their operands are transparent for splicing (row 50). |
| 49 | `&&` / `\|\|` | fundamental, one per run (§3.5) | no | no | [CC pp.7–8]; [SLang] L115–131 | Kept as Sonar. |
| 50 | Plain parentheses `(a && b)`, nested `((a && b))`, and the operand of `try`, `await`, `unsafe`, `consume`, `copy` or `borrow` | none. The contents join the surrounding sequence. | no | no | [Java] L300–301 skips parentheses when flattening a logical expression | Redundant parentheses and effect keywords should not add cost. The parser wraps only one sequence element in these keywords (`P/Expressions.swift:448-562`), so they must be looked through. |
| 51 | Prefix `!`, including `!(a \|\| b)` | none. A parenthesised operand of a prefix operator is a separate sequence. | no | no | The paper's example `a && !(b && c)` scores +2 for the operators [CC p.8]; [Java] flattens only `&&` / `\|\|` nodes (L295–306) | Kept as Sonar. |
| 52 | `??` | none. Does not break a run. | no | no | [CC p.6]; C# ([CSharp] L189–207); JS ([JS] L378–382) | Kept as Sonar. |
| 53 | Optional chaining `?.` | none | no | no | [CC p.6]; [CSharp-tests] CognitiveComplexity.cs L193–198; [Kotlin] L166–167 | Kept as Sonar. |
| 54 | Optional pattern `case let x?` | none | no | no | none | A pattern, not chaining. It parses as an `OptionalChainingExprSyntax` under an `ExpressionPatternSyntax` (checked with the dumper), so exclude those. |
| 55 | Force unwrap `!`, `as!`, `as?`, `is` | none | no | no | none | They produce values or trap. They are not branches. |
| 56 | Key-path optional component `\.a?.b` | none | no | no | none | Not evaluated as a branch at this point. |
| 57 | Comparison, arithmetic and custom operators | none | no | no | [CC p.21, v1.1]: only binary boolean operators count | Kept as Sonar. |
| 58 | Assignment `=`, and `->` in an expression | none. Ends a logical run. | no | no | none | Both have lower precedence than `&&` / `\|\|` (`Sources/SwiftOperators/OperatorTable+Defaults.swift:70-86`), so operators either side never combine. |
| 59 | `#if` inside a function body: in statements, in a switch's case list, or as a postfix `#if` on an expression | structural | yes | yes (clause contents) | [CC p.6, p.9 example] | Kept as Sonar. The reader reads every clause, so every clause is walked ([PRD]:73). A `#if` in a member list or an attribute list is not scored, wherever it appears (§3.3). |
| 60 | `#elseif`, `#else` | hybrid | no | yes | By analogy with `else if` / `else` [CC p.6] | Same reasoning as rows 14–15. |
| 61 | Operators in a `#if` condition, e.g. `os(iOS) && DEBUG` | none | no | no | none | Build settings, not run-time logic. The `#if` increment covers the reading cost. Exclude sequences under `IfConfigClauseSyntax.condition` (`N/SyntaxNodesGHI.swift:2139`). |
| 62 | Freestanding macro (`#expect(a && b)`, `#Predicate { … }`) | none for the macro. Arguments are analysed as written. | no | no for the macro. Closures in its arguments nest (row 4). | none | The reader reads the arguments. The expansion is invisible to syntax. |
| 63 | Attached macros, `macro` declarations | none | no | no | none | No visible control flow. |
| 64 | `then` statement (experimental) | none | no | no | none | Never produced by the default parser: gated on `.thenStatements` (`P/TokenSpecSet.swift:124`). |
| 65 | Direct recursion | fundamental, once per function | no | no | [CC p.8]; [CSharp] L103–113 (direct only) | Kept, but limited to direct recursion found by syntax (§3.4). |
| 66 | Indirect recursion, or a call through another receiver | none (a zero-amount `possibleRecursion` item when the name and labels match, §3.4) | no | no | Deviation from [CC p.8, v1.1] | Needs a call graph or types, which are out of scope. |
| 67 | `self.init(…)` / `super.init(…)` delegation | none | no | no | none | Initialiser delegation is not recursion. |
| 68 | `while true`, `if true` | as their construct | as their construct | as their construct | none | Syntax only, with no constant folding. |

This table answers each PRD §14 Q3 question ([PRD]:494):
- `guard` is a flat +1, not a free exit and not an `if` (row 16).
- A condition list costs +1 once, whatever its order (row 17).
- Optional binding, `if case` and `try?` add nothing (rows 18, 19, 40).
- `defer` adds nesting only (row 8).
- Result-builder bodies count in full (row 9).

### 3.3 Nesting level

The nesting level starts at 0 in every function, including nested functions and local-type members.

**Constructs that raise the level by 1 for the code they contain:**

- `if` / `else if` / `else` bodies, including if-expression branches
- the `guard` `else` body
- `switch` case bodies
- loop bodies
- `catch` bodies
- both branches of a ternary
- `#if` / `#elseif` / `#else` clause contents
- closure bodies
- `defer` bodies

**Things that stay at the outer level:**

- every condition, including `if` / `guard` / `while` conditions, the `repeat` condition, `where` clauses and ternary conditions (but see §3.5.4 for chained ternaries)
- the `switch` subject
- the `for` sequence expression
- the `do` body
- labels
- code after a `guard`

So a closure in an `if` condition sits at the `if`'s own level, plus 1 for the closure. Sonar Java does the same: it scans the condition before raising the level, and raises it only around the then and else parts ([Java] L169–188).

**`else if` chains are flat.** The `else if` `IfExprSyntax` is a syntactic child of the outer `if`'s `elseBody`, but it does not add a level. For an `if` at level *L*, every link's conditions sit at *L*, and every link's body, and the final `else` body, sit at *L* + 1. Sonar Java does this by subtracting the nesting for an `else if` ([Java] L175–183).

**A `guard`'s `else` is not a hybrid `else`.** It costs nothing of its own. It raises the level for its body only.

**`#if` placement.**
- A `#if` among statements sits at the level of those statements.
- A `#if` in a switch's case list sits at the level of the case bodies (the switch's level + 1). The case bodies inside its clauses sit one level deeper.
- A postfix `#if` on an expression sits at the level of that expression.
- A `#if` in a member list (of a top-level type or a local type) is not scored, and it does not change the members' starting level, which stays 0. No function encloses it: local-type members are their own functions, and the parent excludes the local type (§2.1).
- A `#if` in an attribute list is not scored wherever it appears, including on a closure or a local declaration inside a body. Attributes carry no run-time control flow.

**Body containers.** Do not key nesting on `CodeBlockSyntax`. Several bodies are a bare `CodeBlockItemListSyntax`: `ClosureExprSyntax.statements` (`N/SyntaxNodesC.swift:1861`), `SwitchCaseSyntax.statements` (`N/SyntaxNodesQRS.swift:4240`), `AccessorBlockSyntax.Accessors.getter` (`N/SyntaxNodesAB.swift:599`), and `IfConfigClauseSyntax.elements` in its `.statements` case (`N/SyntaxNodesGHI.swift:2157`). Key nesting on the constructs in the lists above.

### 3.4 Recursion detection

A function gets one fundamental increment (rule `recursion`) if its own body contains at least one call where all of these hold. Its own body includes the closures that fold into it, and excludes nested functions, local-type members and local accessors, as for C and D (§2.1). Why: a nested helper that calls the parent forms an indirect cycle, which is out of scope.

1. **The function is an ordinary `func`.** Accessors, subscripts, initialisers and closures are not checked. Operator functions are not checked either. They are almost always called as operator expressions. The exception, `(==)(a, b)`, is a `FunctionCallExprSyntax`, but its callee is a `TupleExprSyntax`, not a bare `DeclReferenceExprSyntax`, so rule 2 can never match it.
2. **The callee names the function.** It is one of:
   - a bare `DeclReferenceExprSyntax` with the function's base name. This covers a bare call inside a `static` function too;
   - a `MemberAccessExprSyntax` on `self` with that name;
   - a `MemberAccessExprSyntax` on `Self` with that name, only when the function has a `static` or `class` modifier. In an instance method, `Self.name` calls a static member.
3. **The name is not shadowed.** A bare call does not match if the function declares anything else with the same base name: a parameter of the function (by its internal name), a nested function, a local variable or constant, a closure parameter, or a local type. `self.name` calls are not affected. Example: in `func apply(_ apply: (Int) -> Int) -> Int { apply(1) }` the labels fit, but `apply` is the parameter, so there is no increment.
4. **The argument labels fit the parameters**, by this rule:
   - The call's labels are each parenthesised argument's label (`_` if it has none), then `_` for the first trailing closure, then the label of each further trailing closure.
   - For each parameter, take its external label, whether it has a default value, whether it is variadic (`...`), and whether its type is syntactically a function type (`FunctionTypeSyntax`, after removing attributes such as `@escaping`, parentheses, and `?` or `!`).
   - Match the call's labels left to right. Each label matches the next unmatched parameter with the same external label. Every parameter skipped on the way must have a default value or be variadic.
   - A matched variadic parameter also takes every following `_` label. Swift requires the parameter after a variadic one to have a label, so this is unambiguous.
   - The first trailing closure instead matches the next unmatched parameter whose type is a function type, whatever its label. Parameters skipped on the way must have a default value or be variadic. This is the forward scan of SE-0286 [SE-0286], reduced to syntax.
   - After the last label, every unmatched parameter must have a default value or be variadic.

The increment is once per function, not once per call, following "each method in a recursion cycle" [CC p.8]. It is skipped when `detectRecursion` is off.

**`possibleRecursion` (zero amount).** It applies only to a function that rule 1 checks (an ordinary `func`, not an initialiser, accessor or closure), over the same own body, and only when `detectRecursion` is on. A call on any other receiver, such as `node.left.depth(of: x)` or `other.sorted { … }`, gets a cognitive item of rule `possibleRecursion` with amount 0 when its base name matches and its labels fit the parameters by rule 4 with every parameter used: no parameter is skipped through its default value, and a variadic parameter takes at least one argument. The first trailing closure binds by rule 4's SE-0286 forward scan, to the next unmatched function-typed parameter whatever its label. So `other.sorted { … }` inside `func sorted(by areInIncreasingOrder: (Element, Element) throws -> Bool)` gets an item: the unlabelled trailing closure binds to `by:`. The item changes no score. It lets SwiftStats measure how often tree-style recursion is missed. `Array.filter { … }` called inside a two-parameter `filter(_:_:)` does not get one, because the arity differs.

**Known errors.**
- False negatives: recursion through another instance (`node.left.depth()`, flagged only as `possibleRecursion`), and indirect cycles.
- False positives: an overload with the same base name and labels, such as `func process(_ x: Int) { process(String(x)) }`. Syntax cannot tell the overloads apart.

### 3.5 Logical-operator sequences on unfolded trees

#### 3.5.1 What the parser gives

swift-syntax does not fold operators.
- An infix expression is a flat `SequenceExprSyntax` (`N/SyntaxNodesQRS.swift:974`). Operands alternate with operator elements (`P/Expressions.swift:156-232`).
- A one-element expression has no wrapper (`P/Expressions.swift:213-215`).
- `&&`, `||` and `??` appear as `BinaryOperatorExprSyntax` elements. Test `operator.text` (`N/SyntaxNodesAB.swift:5211`).
- The ternary appears as `UnresolvedTernaryExprSyntax` (`N/SyntaxNodesTUVWXYZ.swift:2889`). It holds only the `thenExpression`; the else branch is the elements that follow it.
- Assignment appears as `AssignmentExprSyntax`.
- `try`, `await`, `unsafe`, `consume`, `copy` and `borrow` wrap a single sequence element, not the rest of the sequence (`P/Expressions.swift:448-562`). `if unsafe (a && b) && c` parses as a sequence whose first element is an `UnsafeExprSyntax` around a `TupleExprSyntax`.
- Parentheses, call arguments, closure bodies, interpolations, subscripts, the ternary's `thenExpression` and each condition element hold their own nested sequences. For example, `if (a && b), c && d` has two condition elements: a `TupleExprSyntax` holding a sequence, and a bare sequence (checked with the dumper).

**`SwiftOperators` folding is not required.** Do not use it.

- Sonar's implementations count operator changes in source order. SLang flattens the expression and adds +1 whenever the operator text changes ([SLang] L115–131). The flat element list already is that order.
- Folding needs an operator table, and it fails on operators it does not know (`OperatorError.missingOperator`, `Sources/SwiftOperators/OperatorError.swift:32`).
- Folding does not change the answer when the folded tree is walked in order. It would change the answer only if runs were counted by operator groups in the tree, and no rule here does that. For `a || b && c || d`, the in-order walk gives three runs (`||`, `&&`, `||`). The folded tree `(a || (b && c)) || d` has two operator groups, but no rule counts groups.

**Folded input.** A consumer may pass a tree it has already folded with `SwiftOperators`. There, binary operators are `InfixOperatorExprSyntax` nodes, ternaries are `TernaryExprSyntax` and casts are `IsExprSyntax` / `AsExprSyntax`. The library then uses these definitions in place of the `SequenceExprSyntax` ones in §3.5.2, and gets the same token lists:
- **Unwrap** as in §3.5.2. Parentheses survive folding as one-element `TupleExprSyntax` and are looked through. `TryExprSyntax`, `AwaitExprSyntax` and `UnsafeExprSyntax` are looked through around an `InfixOperatorExprSyntax` or a `TernaryExprSyntax` too: SwiftOperators hoists these keywords over the whole folded expression, while the unfolded tree wraps only one element.
- **Spliceable node:** an `InfixOperatorExprSyntax`, `TernaryExprSyntax`, `IsExprSyntax` or `AsExprSyntax`.
- **Root:** a spliceable node that, after unwrapping, is not spliced into another: it is not an operand of an `InfixOperatorExprSyntax`, not the condition or `elseExpression` of a `TernaryExprSyntax`, and not the `expression` of a cast. Skip anything under `IfConfigClauseSyntax.condition`.
- **Token list:**
  - `InfixOperatorExprSyntax`: the left operand's tokens, then its operator's (`&&` or `||` emits itself, `AssignmentExprSyntax` and `ArrowExprSyntax` emit BREAK, any other operator emits nothing), then the right operand's tokens.
  - `TernaryExprSyntax`: its condition's tokens, then BREAK, then its `elseExpression`'s tokens, with no BREAK after. Its `thenExpression` is a separate root, as in the unfolded form.
  - `IsExprSyntax` / `AsExprSyntax`: its `expression`'s tokens. The cast emits nothing.
  - Any operand: unwrap it. If the result is a spliceable node, emit its tokens here. Otherwise emit nothing; a prefix operator's operand, a call or a closure holds its own roots (row 51).

Without these definitions, `(x && y ? b : c && z) && d` scores 2 unfolded but 3 folded, if the folded ternary is treated as an opaque operand.

Ternary nesting in folded trees follows the tree (§3.5.4).

#### 3.5.2 Algorithm

**Unwrap.** To unwrap an expression, repeat until nothing changes:
- a `TupleExprSyntax` with exactly one element and no label becomes that element's expression;
- a `TryExprSyntax`, `AwaitExprSyntax`, `UnsafeExprSyntax`, `ConsumeExprSyntax`, `CopyExprSyntax` or `BorrowExprSyntax` becomes its `expression`.

**Root sequences.** Every `SequenceExprSyntax` that is not spliced into another sequence is a root. A condition element's expression is never spliced into anything: there is no enclosing sequence. So each `.expression` condition element whose unwrapped expression is a sequence is its own root, and is counted once. Skip anything under `IfConfigClauseSyntax.condition`.

**Token list for a root.** Walk `elements` in order:
- `BinaryOperatorExprSyntax` with text `&&` or `||`: emit that operator.
- `BinaryOperatorExprSyntax` with any other text, including `??`, `==` and `+`: emit nothing.
- `UnresolvedTernaryExprSyntax`, `AssignmentExprSyntax` or `ArrowExprSyntax`: emit **BREAK**.
- `UnresolvedIsExprSyntax`, `UnresolvedAsExprSyntax` and their `TypeExprSyntax` operands: emit nothing.
- Any operand: unwrap it. If the result is a `SequenceExprSyntax`, emit its token list here, recursively, and mark it spliced. This is the transparent-parentheses rule (row 50).
- Any other operand emits nothing. That includes a `PrefixOperatorExprSyntax` such as `!(…)`, a call or a closure. Sequences nested inside it are their own roots (row 51).

**Counting.** Add +1 fundamental for each `&&` or `||` token whose predecessor is not the same operator. A BREAK, or the start of the list, counts as "not the same".

**Condition lists.** Separately, an `if`, `guard` or `while` whose `ConditionElementListSyntax` (`Sources/SwiftSyntax/generated/SyntaxCollections.swift:460`) has two or more elements gets +1 fundamental (rule `conditionList`). Elements of every kind count towards the two: `.expression`, `.optionalBinding`, `.matchingPattern` and `.availability`. No synthetic `&&` is inserted between elements. Sequences inside bindings' initialisers are their own roots, as before.

**Examples:**

| Expression | Tokens per root | Logical and list increments |
|---|---|---|
| `a && b && c \|\| d \|\| e && f` | `&& && \|\| \|\| &&` | +3, matching [CC p.8] |
| `a && !(b && c)` | outer `&&`; inner `&&` | +2, matching [CC p.8] |
| `a && (b && c)` and `a && ((b && c))` | `&& &&` (spliced) | +1 |
| `unsafe (a && b) && c` | `&& &&` (spliced through `unsafe`) | +1 |
| `if let a, let b, a > b` | list +1; `a > b` has no logical token | +1 |
| `if a \|\| b, c` | list +1; `\|\|` | +2 |
| `if a, b \|\| c, d` and `if a, d, b \|\| c` | list +1; `\|\|` | +2 for both orders |
| `if (a && b), c` and `if a && b, c` | list +1; `&&` | +2 for both |
| `if a && b && c` and `if a, b, c` | `&& &&`, or list +1 | +1 for both |
| `x = a && b ? c : d \|\| e` | BREAK `&&` BREAK `\|\|` | +2 |

The last column counts only logical-sequence and condition-list increments. It leaves out the statement's own increment (the `if` +1) and, in the last row, the ternary's structural increment.

The last-but-one row keeps SwiftLint's `prefer_condition_list` autocorrect neutral: it rewrites a pure `&&` run as a list, and both score +1.

#### 3.5.3 Decision-count use

The decision count (§4) counts operator tokens, not runs:
- +1 for every `BinaryOperatorExprSyntax` whose text is `&&`, `||` or `??`, anywhere in the function's own body, in spliced or unspliced sequences alike. Unlike the cognitive token list, `??` is counted here.
- "Own body" is as in §2.1: closures fold in, and nested-function, local-accessor and local-type bodies are excluded. Inside a `#if`, only the tokens of the chosen clause count, by the `#if` rule in §4.2.
- +1 for every ternary.
- Nothing under `IfConfigClauseSyntax.condition`.
- Nothing for condition-list commas through this scan. Extra condition elements are counted once, by their own row in §4.2.

#### 3.5.4 Ternary nesting without folding

The ternary is right-associative. Its precedence is below every operator except `->` and assignment: `TernaryPrecedence` is higher only than `FunctionArrowPrecedence`, which is higher only than `AssignmentPrecedence` (`Sources/SwiftOperators/OperatorTable+Defaults.swift:70-86`).

In one `SequenceExprSyntax`, split the elements into **segments** at every `AssignmentExprSyntax` and `ArrowExprSyntax`. In each segment, number the ternaries 1, 2, 3 and so on from the left. Ternary *k* lies in the else branch of ternary *k−1*.

Let *L* be the level of the sequence. That is the level of the position it occupies: for a condition element, the statement's own level; for a sequence inside parentheses, the level of the parenthesised operand's position in the outer sequence. Then, in each segment:
- Ternary *k* gets nesting level *L + k − 1*.
- Its `thenExpression`, and every element of the segment after it, sit at level *L + k*.
- Elements before the segment's first ternary sit at *L*.

This scores every ternary, including one before the last assignment, such as `c ? x : y = 1`.

Examples:
- `a ? b : c ? d : e` scores +1 and then +2.
- `if a ? b : c { … }` is valid Swift (it type-checks). The ternary is in an `.expression` condition element, so it sits at the `if`'s own level, and its BREAK lies inside that element's own root.

**Folded trees.** Nest by tree structure. A `TernaryExprSyntax`'s condition sits at the level where the ternary sits; its `thenExpression` and `elseExpression` sit one level deeper. This gives the same numbers as the unfolded rule.

### 3.6 Walking

- Walk as §2.8 says.
- Visit `IfExprSyntax` and `SwitchExprSyntax` directly, never through `ExpressionStmtSyntax`. In statement position they are wrapped in it, and in expression position they are not (`P/Statements.swift:82-97`; `P/Expressions.swift:604-610`).
- Treat `DoExprSyntax` and `ThenStmtSyntax` like their statement forms, for forward compatibility. The default parser never produces them (`P/TokenSpecSet.swift:749`, `P/Statements.swift:71`, `P/TokenSpecSet.swift:124`).

---

## 4. Swift decision count, and the SwiftLint-compatible count

### 4.1 Definition

`decisionCount` (D) is the number of run-time decision points in the function. **The base value is 0.** The library also exposes `mccabe = D + 1`. That is McCabe's v(G) for a function ([McCabe76]; [NIST] §2.2, §4.1).

Counting principles:

- Count a construct only if it creates an edge that normal, non-trapping execution may take or skip.
- Count short-circuit operators, as NIST does ([NIST] §4.1).
- For a multiway decision, add the number of outgoing edges minus 1 ([NIST] §4.1).
- Do not count traps, unconditional jumps, or compile-time selection.

Closures, nested functions and local types follow the function rules in §2.1.

### 4.2 Decision table

| Construct | +n | Rationale |
|---|---|---|
| `if` (statement or expression) | +1 | A binary decision. |
| `else if` | +1 | A nested `IfExprSyntax`, so another decision. |
| `else` | 0 | The false edge of a decision already counted. |
| `guard` | +1 | A binary decision. |
| Each condition element after the first in an `if` / `guard` / `while` list (boolean, optional binding, `case` pattern, `#available`) | +1 each | Evaluation stops at the first failure [SE-0099], so `a, b` has the edges of `a && b`. Lizard also counts commas ([Lizard] `swift_conditions.py`). |
| Optional binding, `if case` pattern, `#available` as the only element | 0 extra | One element is one predicate, already counted by its statement. |
| `switch` (statement or expression) | + max(0, arms − 1) | NIST: outgoing edges minus 1. An arm is a `SwitchCaseSyntax`, including `default` and `@unknown default`. Swift switches are exhaustive, so there is no implicit default edge. A two-arm switch equals `if` / `else`. `switch n {}` on a `Never` value has no arms and scores 0, as in SwiftLint. Arms inside `#if` follow the `#if` rule below. |
| Multi-pattern case `case .a, .b:` | 0 extra | Several labels on one statement are one outcome edge ([NIST] §4.1, Figure 4-6). |
| `where` (`WhereClauseSyntax`) on a case item, a `for`, or a catch item | +1 each | A run-time boolean that can fail. |
| An arm whose only statement is `fallthrough` | not counted as an arm | It merges labels: `case 0: fallthrough; case 1:` is `case 0, 1:`. |
| Any `fallthrough` that is not its case's only statement | 0 | An unconditional jump. The arm is a distinct outcome and still counts. |
| Ternary `?:` (`UnresolvedTernaryExprSyntax` or `TernaryExprSyntax`, never both) | +1 | A binary decision. |
| `&&`, `\|\|` | +1 each | They short-circuit. The standard library's right-hand side is `@autoclosure` ([NIST] §4.1). Not counted inside `#if` conditions. |
| `??` | +1 each | The right-hand side is an `@autoclosure`, evaluated only when the left side is `nil`. That is a real conditional edge. Sonar's C# metric counts `??` ([Sonar-metrics]). |
| Optional chaining `?.` | 0 | The whole chain collapses to one `nil` outcome. `delegate?.x()` is ubiquitous and expresses an optional receiver more than a choice. It would be the noisiest construct to count. See Q14. |
| `for-in`, including `for try await` | +1 | Each iteration decides whether to continue. |
| `for case <pattern> in` | +1, unless the pattern is irrefutable (defined below the table) | A refutable pattern silently skips elements. `for case let (a, b) in pairs` adds nothing; `for case let x? in xs` adds 1. Keyed on `ForStmtSyntax.caseKeyword` (`N/SyntaxNodesEF.swift:2528`). |
| `while` | +1, plus extra condition elements | Loop test. |
| `repeat { } while c` | +1 | Loop test. |
| `catch` clause | +1 each | Each handler is a distinct edge. |
| `catch A, B` | 0 extra | Labels, as for multi-pattern cases. |
| `do`, `do throws(E)` | 0 | No branch. |
| `try`, `try?` | 0 | The implicit error edge of a throwing call is not counted. If it were, every call would add. `try?` converts that edge to a value. |
| `try!`, `!`, `as!` | 0 | Traps. |
| `as?`, `is` | 0 | Values. The test is counted where the value is used. |
| `throw`, `return`, `break`, `continue` (labelled or not) | 0 | Unconditional exits and jumps. |
| `defer` | 0. Its contents count. | Runs on every exit. |
| `#if` / `#elseif` / `#else` | 0 for the directive. Contents count as the **maximum over clauses**, recursively (rule below). | Selection happens at compile time, so one build runs one clause. The maximum is the worst single configuration and needs no build settings. |
| `async let`, `await`, `Task {}`, closures | 0. Closure contents fold in. | Not decisions. |
| `forEach`, `map`, SwiftUI `ForEach` | 0. Closure contents fold in. | Calls, not loops in syntax. This undercounts relative to `for-in`, and that is documented. |
| Builder `if` / `switch` / `for` | counted normally | Real run-time branches. |
| Recursion | 0 | Not a decision. |
| Freestanding macro arguments | counted as written | Visible source. The expansion is not visible. |
| `repeat each` | 0 | Not a loop. |

**Irrefutable `for case` patterns.** The test is defined on the parse shapes swift-syntax 603.0.2 produces. Remove every `ValueBindingPatternSyntax` wrapper, at any depth. The pattern is then irrefutable when it is:
- an `IdentifierPatternSyntax` or a `WildcardPatternSyntax`;
- a `TuplePatternSyntax` whose every element's pattern is irrefutable; or
- an `ExpressionPatternSyntax` whose expression is irrefutable.

An expression is irrefutable when it is a `DiscardAssignmentExprSyntax` (`_`), a `PatternExprSyntax` whose pattern is irrefutable, or a `TupleExprSyntax` whose every element's expression is irrefutable, applied recursively. Everything else is refutable: an optional pattern (`x?`), an enum case, a cast, a literal or any other expression.

Examples, as parsed:
- `for case let (a, _) in xs` is `ValueBindingPatternSyntax(ExpressionPatternSyntax(TupleExprSyntax(PatternExprSyntax(IdentifierPatternSyntax), DiscardAssignmentExprSyntax)))`: irrefutable, +0.
- `for case (let a, let b) in xs` is `ExpressionPatternSyntax(TupleExprSyntax(PatternExprSyntax(ValueBindingPatternSyntax(IdentifierPatternSyntax)), …))`: irrefutable, +0.
- `for case _ in xs` is `ExpressionPatternSyntax(DiscardAssignmentExprSyntax)`: irrefutable, +0.
- `for case let x? in xs` and `for case .some(let x) in xs`: refutable, +1.

**The `#if` rule.**
- Each `#if` has a list of clauses. A missing `#else` counts as an empty clause.
- Pick the clause with the largest value, recursively for `#if`s inside it. In a statement or expression position, a clause's value is the decisions inside it. In a switch's case list, it is the counted arms inside it (fallthrough-only arms excluded) plus the decisions inside it.
- A tie goes to the first clause in source order.
- The switch's arm count is its unconditional arms plus the arms of every chosen clause. Then apply max(0, arms − 1).
- The breakdown holds the items of the chosen clauses only, so the items still sum to D.

**Trivial switches (lint only).** With `decisionCountIgnoresTrivialSwitches` on, a switch costs +1 instead of max(0, arms − 1) (rule `trivialSwitch`) when all of these hold:
- it has at least two counted arms;
- every arm's body is exactly one statement, and that statement contains no construct D counts, including inside closures in that statement. A fallthrough-only arm is one statement, so it does not stop a switch being trivial;
- no case item has a `where`, and its case list has no `#if`.

This is a lookup table: NIST §2.5 notes McCabe's own exemption for modules made of one multiway decision, and also warns against changing the measure itself [NIST]. So the option is off by default, SwiftStats leaves it off and stores raw D, and SwiftProjectLint turns it on for its threshold (§14.2). In the calibration it took a 61-arm status-code table from D = 60 to D = 1.

Worked check (probe 3, Appendix A):

```swift
func probe(_ c: Int) -> Int {
    guard let a = Optional(c), c > 1 else { return 0 }
    for x in [1, 2] where x > 0 { print(x) }
    switch c {
    case 1, 2: return 1
    case 3 where a > 2: return 2
    default: break
    }
    return c > 0 ? 1 : 2
}
```

- D = 8: guard 1 + extra element 1; `for` 1 + `where` 1; three arms 2 + `where` 1; ternary 1. `mccabe` = 9.
- SL = 5: guard, `for` and three cases (SwiftLint 0.65.1).

### 4.3 SwiftLint-compatible count

This reproduces `cyclomatic_complexity` from the SwiftLint source at commit `ec4691d9e8` (2026-09-28), checked by probe against SwiftLint 0.65.1. Probes p1 and p2 are reproduced in Appendix A, and become test fixtures in the library at `Tests/SwiftCodeMetricsTests/Fixtures/`. [CCR] is `~/GitHub_projects/SwiftLint/Source/SwiftLintBuiltInRules/Rules/Metrics/CyclomaticComplexityRule.swift`.

| Rule | Value | Evidence |
|---|---|---|
| Scored declarations | `func` and `init` with a body only | [CCR]:78-86, 88-94 |
| Base | 0 | [CCR]:117, 97-99 |
| Violation | `complexity > threshold`; defaults warning 10, error 20 | [CCR]:101; [CCC]:7 |
| `for` | +1 | [CCR]:125 |
| `if`, including each `else if` | +1 | [CCR]:129 |
| `guard` | +1 | [CCR]:133 |
| `repeat` | +1 | [CCR]:137 |
| `while` | +1 | [CCR]:141 |
| `catch` | +1 | [CCR]:145 |
| `case`, including `default` and `@unknown default` | +1 each, unless `ignores_case_statements` | [CCR]:149-153 |
| `fallthrough` | −1 each, unless `ignores_case_statements` | [CCR]:155-160 |
| `ignores_case_statements` | default false | [CCC]:8-9 |
| `switch n {}` | 0 | probe |
| Nested `func` / `init`, at any depth, including local-type `func` and `init` | skipped (own score) | [CCR]:162-168; outer visitor skips nothing ([VSV]:29) |
| Closures | folded in | not skipped by [CCR]:162-168 (probe) |
| Local-type implicit getters, explicit accessors, subscripts, `deinit` and stored-property initial values, including members inside a member-list `#if` | folded into the enclosing `func` or `init` | only `func` and `init` are skipped, [CCR]:162-168 (probes p1, p2) |
| Local computed variables and `willSet` / `didSet` observers in the body | folded into the enclosing `func` or `init` | probe p1 |
| Default argument values | not counted, in either function | probe p2 |
| `#if` clauses, including clauses in a switch's case list | all clauses summed | `viewMode: .sourceAccurate`, [CCR]:122 (probe p2: four cases across two clauses gave 4) |
| Not counted | `&&`, `\|\|`, `??`, `?:`, extra condition elements, `where`, `for case`, multi-pattern cases | probe |

**How the library applies this to its own functions.**
- Every function gets an SL value, computed over its own body by the rules above.
- The SL of a `func` or `init` includes the bodies SwiftLint folds in: local-type getters, accessors, subscripts, `deinit` and stored-property initial values, and local computed and observed variables. These are also functions in their own right, with their own SL (§2.1). So their bodies are counted twice: once in the parent, once in themselves.
- Each record says whether SwiftLint itself scores that kind of function (`swiftLintScoresKind`, true only for `func` and `init`). A consumer comparing totals with SwiftLint sums SL over records where `swiftLintScoresKind` is true. That sum has no double counting, and it equals SwiftLint's. SwiftStats marks the other values as SwiftStats-only ([PRD]:147).

SwiftLint's counting has changed between versions. It was rewritten with SwiftSyntax in 0.54.0 (`CHANGELOG.md:1996`, under the 0.54.0 heading at line 1971). The SourceKit version did not count `catch`: the `defaultComplexityStatements` in `git show 715198ae3^:Source/SwiftLintBuiltInRules/Rules/RuleConfigurations/CyclomaticComplexityConfiguration.swift` has no `catch`. It did score accessors: `SwiftDeclarationKind.functionKinds` at the same commit includes the accessor kinds. So consumers should record the SwiftLint version they compare against.

### 4.4 Differences between the decision count and the SwiftLint-compatible count

1. **Operators.** D counts `&&`, `||`, `??` and ternaries. SwiftLint counts none of them.
2. **Condition lists.** D adds +1 for each condition element after the first. SwiftLint adds nothing.
3. **switch.** D adds max(0, arms − 1). SwiftLint adds one per arm, `default` included. So SwiftLint = (mccabe − 1) + (number of switches) when all of these hold:
   - no `&&`, `||`, `??` or ternaries;
   - no condition list with more than one element;
   - no `where` and no counted `for case`;
   - no `#if` with decisions or arms in more than one clause;
   - no local-type or local-variable bodies that SwiftLint folds in;
   - every switch has at least one arm, and every `fallthrough` is its case's only statement. A fallthrough-only arm is fine: D drops the arm and SwiftLint subtracts 1 for it, so both lose one;
   - `ignores_case_statements` is false, and `decisionCountIgnoresTrivialSwitches` is off.
4. **where.** D adds +1 for each `where` on a case, a `for` or a catch item. SwiftLint adds nothing.
5. **for case.** D adds +1 for a refutable pattern. SwiftLint adds nothing extra.
6. **fallthrough.** D drops arms whose only statement is `fallthrough`. SwiftLint subtracts 1 for every `fallthrough`, even after other code.
7. **#if.** D takes the maximum over clauses. SwiftLint sums all clauses.
8. **Function kinds.** SwiftLint scores only `func` and `init`. The library computes SL for every function, flagged by `swiftLintScoresKind`.
9. **Local bodies.** D scores local-type members and local computed and observed variables as their own functions, and leaves them out of the parent. SL folds their bodies (all but `func` and `init`) into the parent, as SwiftLint does.
10. **Configuration.** `ignores_case_statements` affects only SL. `decisionCountIgnoresTrivialSwitches` affects only D.
11. **No difference** for `if`, `else if`, `guard`, `for`, `while`, `repeat` and `catch` (+1 each in both), or for closures (folded in both). The base is 0 in both. `mccabe` adds 1.

---

## 5. Result-builder hint

Result-builder bodies count in full (§3.2 row 9). The library reports a `resultBuilderHint` for each function, so a linter can apply a builder threshold (§14.2). It is set by the first of these that applies:

1. **`.attribute(name)`**: an attribute whose last name component ends in `Builder`, matched as `IdentifierTypeSyntax` or `MemberTypeSyntax`, on the `func`, property, subscript or accessor. `name` is the last name component, so `@SwiftUI.ViewBuilder` gives `"ViewBuilder"`. The module qualifier adds nothing a threshold needs, and one spelling keeps stored records comparable.
2. **`.opaqueResult(name)`**: a `func` return type, or a computed property or subscript type, of the form `some P` (`SomeOrAnyTypeSyntax` with `some`, `N/SyntaxNodesQRS.swift:1365`), where the last name component of `P`, or of any member of a composition `some P & Q`, is in `opaqueResultBuilderProtocols`. The default set is `View`, `Scene`, `Commands`, `ToolbarContent`, `CustomizableToolbarContent`, `Widget`, `WidgetConfiguration`, `ChartContent`, `MapContent`, `TableColumnContent` and `TableRowContent`. These protocols' bodies are result builders, and a helper returning one is built from builder container closures.
3. `.none` otherwise.

Rule 2 covers `var body: some View` and also helpers such as `private var toolbar: some View`. In SwiftProjectLint's App target, 52 declarations return `some View`, 32 of them `var body`, and only 3 carry `@ViewBuilder`. The first draft's hint missed about 17 helpers.

This closes the attribute-matching gaps in `viewBuilderComplexity` ([VBC]:90-99; §14.3). SwiftProjectLint could reuse the hint in `viewBuilderComplexity` too.

---

## 6. Worked examples: complexity

Line 1 is the declaration line. "Nest" is the nesting increment added to a structural increment. **C** is cognitive complexity, **D** the decision count and **SL** the SwiftLint-compatible count.

Every SL value below was checked with SwiftLint 0.65.1 on copies of these examples (`only_rules: [cyclomatic_complexity]`, `warning: 0`). Example 6.9 is a getter, which SwiftLint does not score; its SL was checked by pasting the same body into a `func`.

Unless stated, `decisionCountIgnoresTrivialSwitches` is off.

### 6.1 Guard-heavy validator

```swift
func validate(_ form: SignUpForm) throws -> Account {
    guard let name = form.name, !name.isEmpty else {
        throw ValidationError.missingName
    }
    guard let email = form.email, email.contains("@") else {
        throw ValidationError.invalidEmail
    }
    guard form.age >= 18 || form.hasGuardianConsent else {
        throw ValidationError.underage
    }
    return Account(name: name, email: email)
}
```

| Line | Construct | C |
|---|---|---|
| 2 | `guard` (fundamental) | +1 |
| 2 | condition list, two elements | +1 |
| 5 | `guard` | +1 |
| 5 | condition list, two elements | +1 |
| 8 | `guard` | +1 |
| 8 | `\|\|` run | +1 |

- **C = 6.**
- **D = 6**: line 2 has guard 1 + extra element 1; line 5 the same; line 8 has guard 1 + `||` 1. `mccabe` = 7.
- **SL = 3**: three guards.

Top-level guards cost the same under the structural and the fundamental rule, so this example is unchanged by row 16.

### 6.2 Flat switch

```swift
func label(for status: Subscription.Status) -> String {
    switch status {
    case .active, .trial:
        return "Active"
    case .suspended(let reason) where reason == .payment:
        return "Payment due"
    case .suspended:
        return "Suspended"
    case .cancelled, .expired:
        return "Ended"
    }
}
```

| Line | Construct | C |
|---|---|---|
| 2 | `switch` | +1 |
| 3, 9 | multi-pattern cases | 0 |
| 5 | `where` | 0 |

- **C = 1.**
- **D = 4**: four arms give +3, and `where` gives +1. The `where` stops the switch from being trivial, so the lint option does not change it.
- **SL = 4**: four cases.

### 6.3 Nested loops with a labelled break

```swift
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
```

| Line | Construct | C |
|---|---|---|
| 3 | `for` (nest 0) | +1 |
| 4 | `for` (nest 1) | +2 |
| 5 | `if` (nest 2) | +3 |
| 7 | `break outer` (fundamental) | +1 |

- **C = 7.** This is the same shape as the paper's `sumOfPrimes`, which scores 7 [CC p.10].
- **D = 3.**
- **SL = 3.**

### 6.4 `if let` chain

```swift
func displayName(for user: User?) -> String {
    if let user, let nickname = user.nickname, !nickname.isEmpty {
        return nickname
    } else if let user {
        return user.fullName
    } else {
        return "Guest"
    }
}
```

| Line | Construct | C |
|---|---|---|
| 2 | `if` | +1 |
| 2 | condition list, three elements | +1 |
| 4 | `else if` (hybrid); one element, no list increment | +1 |
| 6 | `else` (hybrid) | +1 |

- **C = 4.**
- **D = 4**: `if` 1 + two extra elements 2 + `else if` 1.
- **SL = 2.**

### 6.5 Optional chaining

```swift
func cityLabel(for order: Order?) -> String {
    let city = order?.customer?.address?.city?.capitalized
    order?.delegate?.didRequestLabel(for: order)
    return city ?? "Unknown"
}
```

| Line | Construct | C |
|---|---|---|
| 2–3 | six `?.` links | 0 |
| 4 | `??` | 0 |

- **C = 0.**
- **D = 1**: the `??`.
- **SL = 0.**

### 6.6 `??` chain

```swift
func timeout(override: Int?, environment: [String: String], config: Config?) -> Int {
    override
        ?? environment["TIMEOUT"].flatMap(Int.init)
        ?? config?.timeout
        ?? 30
}
```

- **C = 0.** `??` and `?.` are ignored.
- **D = 3**: three `??`.
- **SL = 0.**

### 6.7 Mixed `&&` / `||` sequence

```swift
func canEdit(_ user: User, _ document: Document) -> Bool {
    if user.isBanned { return false }
    return user.isAdmin
        || document.ownerID == user.id && !document.isLocked
        || document.isShared && !(user.isGuest || document.isArchived)
}
```

| Line | Construct | C |
|---|---|---|
| 2 | `if` | +1 |
| 3–5 | outer tokens `\|\| && \|\| &&`: four runs | +4 |
| 5 | `!( … \|\| … )`: a separate root | +1 |

- **C = 6.** The in-order walk gives the same six on a folded tree. Counting operator groups in the folded tree would give 5, because the outer operators fold into one `||` group and two `&&` groups. No rule counts groups (§3.5.1).
- **D = 6**: `if` 1 + two `&&` + three `||`.
- **SL = 1.**

### 6.8 Closure-heavy function

```swift
func verifiedEmails(in teams: [Team]) -> [String] {
    teams
        .filter { $0.isActive }
        .flatMap { team in
            team.members.compactMap { member in
                guard member.isVerified else { return nil }
                return member.email.isEmpty ? nil : member.email
            }
        }
        .sorted { $0.lowercased() < $1.lowercased() }
}
```

| Line | Construct | C |
|---|---|---|
| 3 | closure (level 1 inside, no control flow) | 0 |
| 4 | closure: level 1 | 0 |
| 5 | nested closure: level 2 | 0 |
| 6 | `guard` (fundamental, no nesting increment) | +1 |
| 7 | ternary (nest 2, all from closures) | +3 |
| 10 | closure | 0 |

- **C = 4.** The first draft gave 6, with the guard at +3.
- **D = 2.**
- **SL = 1**: SwiftLint does not count the ternary.

### 6.9 SwiftUI body with `if` and `ForEach`

```swift
var body: some View {
    List {
        if items.isEmpty {
            ContentUnavailableView("No items", systemImage: "tray")
        } else {
            ForEach(items) { item in
                HStack {
                    Text(item.title)
                    if item.isFlagged {
                        Image(systemName: "flag.fill")
                    }
                }
            }
        }
    }
    .toolbar {
        if canAdd {
            ToolbarItem { AddButton() }
        }
    }
}
```

| Line | Construct | C |
|---|---|---|
| 2 | `List` closure: level 1 | 0 |
| 3 | `if` (nest 1; 1 from closures) | +2 |
| 5 | `else` (hybrid); body at level 2 | +1 |
| 6 | `ForEach` closure: level 3 | 0 |
| 7 | `HStack` closure: level 4 | 0 |
| 9 | `if` (nest 4; 3 from closures) | +5 |
| 16 | `.toolbar` closure: level 1 | 0 |
| 17 | `if` (nest 1; 1 from closures) | +2 |

- **C = 10.** Closures supply 5 of the 6 nesting points (`closureNesting`, §13). §14.2 deals with this through a threshold.
- **D = 3.**
- **SL = 3**, computed, but SwiftLint does not score getters ([CCR]:78-94), so `swiftLintScoresKind = false`.
- `resultBuilderHint = .opaqueResult("View")`.

### 6.10 Recursion

```swift
func depth(of node: TreeNode?) -> Int {
    guard let node else { return 0 }
    return 1 + max(depth(of: node.left), depth(of: node.right))
}
```

| Line | Construct | C |
|---|---|---|
| 2 | `guard` | +1 |
| 3 | direct recursion, once per function (two calls; labels `of:` match) | +1 |

- **C = 2.**
- **D = 1.**
- **SL = 1.**

### 6.11 `do` / `catch` with several catches

```swift
func loadConfig(from url: URL, attempt: Int = 0) -> Config {
    do {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Config.self, from: data)
    } catch let error as DecodingError where error.isRecoverable {
        return .fallback
    } catch is DecodingError, is CocoaError {
        return .default
    } catch {
        if attempt < 3 {
            return loadConfig(from: url, attempt: attempt + 1)
        }
        return .default
    }
}
```

| Line | Construct | C |
|---|---|---|
| 2 | `do` | 0 |
| 5 | `catch` (nest 0); `where` free | +1 |
| 7 | `catch`, two items | +1 |
| 9 | `catch` | +1 |
| 10 | `if` (nest 1) | +2 |
| 11 | direct recursion (labels `from:attempt:` match) | +1 |

- **C = 6.**
- **D = 5**: three catches, one `where`, one `if`.
- **SL = 4**: three catches and one `if`.

### 6.12 `async let` and `Task`

```swift
func refresh() async {
    async let profile = api.fetchProfile()
    async let feed = api.fetchFeed()
    do {
        let (newProfile, newFeed) = try await (profile, feed)
        self.profile = newProfile
        self.feed = newFeed.filter { !$0.isHidden }
    } catch {
        Task { @MainActor in
            if self.isVisible {
                self.showError(error)
            }
        }
    }
}
```

| Line | Construct | C |
|---|---|---|
| 2–3 | `async let` | 0 |
| 7 | closure, no control flow | 0 |
| 8 | `catch` (nest 0); body at level 1 | +1 |
| 9 | `Task` closure: level 2 | 0 |
| 10 | `if` (nest 2) | +3 |

- **C = 4.**
- **D = 2.**
- **SL = 2.**

### 6.13 `if` and `switch` expressions

```swift
func shippingCost(for order: Order) -> Decimal {
    let base: Decimal = switch order.region {
    case .domestic: 5
    case .europe: 12
    case .worldwide: 20
    }
    let express: Decimal = if order.isExpress { 10 } else { 0 }
    return order.total > 100 ? 0 : base + express
}
```

| Line | Construct | C |
|---|---|---|
| 2 | `switch` expression | +1 |
| 7 | `if` expression | +1 |
| 7 | `else` | +1 |
| 8 | ternary | +1 |

- **C = 4.**
- **D = 4**: three arms give +2, plus `if` and the ternary. With `decisionCountIgnoresTrivialSwitches` on, the switch is a lookup table and costs +1, so the lint value is 3.
- **SL = 4**: three cases and one `if`.

### 6.14 `#if`

```swift
func defaultLevel(verbose: Bool) -> LogLevel {
    #if DEBUG
    if verbose { return .trace }
    return .debug
    #else
    if verbose { return .info }
    return .warning
    #endif
}
```

| Line | Construct | C |
|---|---|---|
| 2 | `#if` (structural, nest 0) | +1 |
| 3 | `if` (nest 1) | +2 |
| 5 | `#else` (hybrid) | +1 |
| 6 | `if` (nest 1) | +2 |

- **C = 6.** The `#if` and the nested `if` follow the paper's `#if DEBUG` example [CC p.9]. That example has no `#else`; the `#else` hybrid comes from row 60.
- **D = 1**: the maximum of the two clauses, the first winning the tie.
- **SL = 2**: both clauses summed ([CCR]:122).

### 6.15 `fallthrough`

```swift
func priority(of statusCode: Int) -> Int {
    var score = 0
    switch statusCode {
    case 500...:
        score += 10
        fallthrough
    case 400..<500:
        score += 5
    case 0:
        fallthrough
    case 1:
        score = 1
    default:
        break
    }
    return score
}
```

| Line | Construct | C |
|---|---|---|
| 3 | `switch` | +1 |
| 6 | `fallthrough` after code (fundamental) | +1 |
| 10 | `fallthrough` as the only statement | 0 |

- **C = 2.**
- **D = 3**: five arms, minus the fallthrough-only arm, is four, which gives +3. The first arm has two statements, so the switch is not trivial.
- **SL = 3**: five cases minus two `fallthrough`s. It agrees with D here by coincidence.

### 6.16 Nested function

```swift
func render(_ rows: [Row]) -> String {
    func cell(_ value: Int?) -> String {
        guard let value else { return "-" }
        return value < 0 ? "(\(-value))" : "\(value)"
    }
    return rows
        .map { row in row.values.map(cell).joined(separator: " | ") }
        .joined(separator: "\n")
}
```

| Function | C | D | SL |
|---|---|---|---|
| `render(_:)` | 0 (the closure has no control flow; `cell` is excluded) | 0 | 0 ([CCR]:162-168) |
| `cell(_:)` | 2: `guard` +1, ternary +1 at nest 0 | 2 | 1 |

Sonar's specification would fold `cell` into `render` at nesting 1 [CC p.9]. Under this specification's construct rules, the folded `render` would score 3: `guard` +1 (fundamental, row 16) and the ternary +2 (+1, nesting 1). It would score 4 if `guard` were scored as an `if`, as Sonar's own rules would score it, having no `guard` rule. This library deviates on purpose (§2.1).

### 6.17 Nested guard chain (row 16)

```swift
func firstValidToken(in lines: [String], strict: Bool) -> Token? {
    for line in lines {
        guard !line.isEmpty else { continue }
        guard let token = Token(line) else {
            if strict {
                log("bad token: \(line)")
            }
            continue
        }
        guard token.isSigned || !strict else { continue }
        return token
    }
    return nil
}
```

| Line | Construct | C, first draft (guard structural) | C, this specification |
|---|---|---|---|
| 2 | `for` (nest 0) | +1 | +1 |
| 3 | `guard` at level 1 | +2 | +1 |
| 4 | `guard` at level 1 | +2 | +1 |
| 5 | `if` in the guard's `else` body, level 2 | +3 | +3 |
| 10 | `guard` at level 1 | +2 | +1 |
| 10 | `\|\|` run | +1 | +1 |

- **C = 8** (first draft: 11). The guards no longer pay for the loop's nesting, but the `if` inside a guard's `else` body still does.
- **D = 6**: `for` 1, three guards 3, `if` 1, `||` 1. `mccabe` = 7.
- **SL = 5**: `for`, three guards and one `if`.

### 6.18 Condition-list order (row 17)

```swift
func shouldSyncA(_ item: Item, now: Date) -> Bool {
    if item.isDirty, item.isOnline || item.forceSync, let last = item.lastSync, now > last {
        return true
    }
    return false
}

func shouldSyncB(_ item: Item, now: Date) -> Bool {
    if item.isDirty, let last = item.lastSync, now > last, item.isOnline || item.forceSync {
        return true
    }
    return false
}
```

The two functions differ only in where the `||` element sits.

| Construct | A, first draft | B, first draft | A and B, this specification |
|---|---|---|---|
| `if` | +1 | +1 | +1 |
| condition list | tokens `&& \|\| && &&`: 3 runs, +3 | tokens `&& && && \|\|`: 2 runs, +2 | +1 once |
| `\|\|` element as its own root | (included above) | (included above) | +1 |

- **C = 3** for both. The first draft gave A = 4 and B = 3.
- **D = 5** for both: `if` 1 + three extra elements 3 + `||` 1. `mccabe` = 6.
- **SL = 1** for both.

---

# Part B: coupling and cohesion

Part B defines the coupling and cohesion measures listed in §1.1. Every value here is a census value in the sense of PRD §6.4: it counts something and claims no defect. SwiftProjectLint turns values into defects by applying thresholds. SwiftStats stores the values and builds signals from them. Types, members, stored properties, modules, `#if` and macros are defined in §2.

The library walks caller-parsed trees with `SyntaxVisitor`. It never type-checks, builds or reads an index store.

Corpus figures quoted below ("the prototype") come from a throwaway syntax-only prototype run on 2026-11-17 over swift-collections, swift-nio, GRDB.swift, swift-composable-architecture (TCA), SwiftStats and SwiftProjectLint. It is not part of any project. It implemented an earlier version of these rules, so its figures are indicative, not reproductions of this specification. §12.7 gives hand counts under the rules as written here.

---

## 7. Shared name resolution

Every metric resolves names the same way. The library implements this once and every visitor uses it.

### 7.1 Two passes

1. **File pass (per file, parallel).** It records declarations and raw references. Declarations: types, extensions, members with their keys, stored properties, enum cases with their payload types, top-level `var`/`let` (globals), top-level functions, typealiases (`TypeAliasDeclSyntax`, N/SyntaxNodesTUVWXYZ.swift:1858), associated types and imports. Raw references: call sites, type names and unqualified value names, each with its lexical-lookup result.
2. **Module pass (needs every file of the module).** It merges extensions into types, builds the module symbol table and resolves the raw references against it. A lookup result that points at a type's members can only be finished here, because the member may be declared in another file's extension.

### 7.2 Value names (locals, members, globals)

For an unqualified `DeclReferenceExprSyntax` (N/SyntaxNodesD.swift:642; `.baseName`, `.argumentNames`):

1. **Names that are not looked up.**
   - A base name of `$` followed by digits (`$0`, `$1`) is an implicit closure parameter. It is not coupling.
   - If `baseName.identifier` is nil, do not call lookup. `TokenSyntax.identifier` (`Sources/SwiftSyntax/TokenSyntax.swift:152`) is nil for every token except identifiers and dollar identifiers, so this covers `self`, `Self`, `super` and `init`. Why: `lookup(nil)` returns every visible name (SLL/Scopes/ScopeSyntax.swift:43–48). `self` and `super` are handled at the end of this section.
2. **Lookup.** Call the public `SyntaxProtocol.lookup(_:with:)` (SLL/Scopes/ScopeSyntax.swift:43) with `node.baseName.identifier`. Results run from the innermost scope outwards. `LookupResult` has four cases (SLL/LookupResult.swift:16–47).
3. **Walk the results in order.** The first rule that applies ends the walk.
   - `.fromScope(_, withNames:)` with a non-empty name list (:18): the name is a local, a parameter, a closure parameter or a capture. It is not coupling. (An empty list never occurs, because `getResultArray` drops it, SLL/LookupResult.swift:77–81. Skip one if it does.)
   - `.lookForGenericParameters(of:)` (:34): check the generic parameters of the extended type's primary declaration, from the module table. If one has the name, it is a generic parameter and not coupling. Otherwise skip this result. Why: inside an extension, lookup puts this result before `.lookForMembers` (SLL/Scopes/ScopeImplementations.swift:405–420).
   - `.lookForImplicitClosureParameters` (:47): skip it. Why: a closure without a parameter clause puts this result before everything outside the closure (ScopeImplementations.swift:186–194), and step 1 has already handled `$n`.
   - `.lookForMembers(in:)` (:20): map `in:` to its type (for an extension, the extended type). The first such result names the innermost type; later ones name enclosing types.
     - If the innermost type, merged with its extensions, declares a `static` or `class` member or stored property with that base name, the name is a **static of that type**. If it declares an instance member or stored property with that name, the name is an **own member**. When it declares both, the enclosing function decides: in a `static` or `class` function the name is the static, elsewhere the instance member. A declaration in its in-module superclass chain (§7.3) makes it an **inherited member**, or a static of that superclass if it is `static` or `class`.
     - If an enclosing type declares the name as `static` or `class`, it is a static of that enclosing type.
     - If an enclosing type declares it as an instance member, skip the result. A nested type cannot reach its parent's instance members by bare name.
     - Otherwise skip the result.
4. **After the walk.** If the module declares a top-level variable with that name, it is a **global**. The file scope introduces no names except top-level `guard` bindings (SLL/Scopes/ScopeImplementations.swift:34–61), so globals always come from the module table, never from lookup.
5. Otherwise, if the module declares a top-level function with that name, it is a **module free function**.
6. Otherwise the name is **unresolved**. That means a member inherited from outside the module, a protocol-default member, a macro-added member or an imported global. It produces no edge.

`self.x` and `self?.x` are always member references: a `MemberAccessExprSyntax` (N/SyntaxNodesJKLMN.swift:3687; `.base`, `.declName`) whose base is `self`, or an `OptionalChainingExprSyntax` around `self`. `super.x` is an inherited-member reference. `Self.x` is a static of the type.

**Real cases this handles:**

- In `Heap._checkInvariants(node:min:max:)`, the parameters `min`/`max` shadow Heap's computed `min`/`max` (`~/GitHub_projects/swift-collections/Sources/HeapModule/Heap+Invariants.swift:40–49`).
- In `MarkedCircularBuffer`, a setter's `var index` shadows the method `index(...)` (`~/GitHub_projects/swift-nio/Sources/NIOCore/MarkedCircularBuffer.swift:165`).
- In an extension, a bare stored-property name is preceded by `.lookForGenericParameters` (§12.1 `totalPrice` and `isStale`).
- In a SwiftUI builder closure or any trailing closure without parameters, a bare member is preceded by `.lookForImplicitClosureParameters` (SwiftProjectLint `ContentView.body`, `~/xcode_projects/SwiftProjectLint/Sources/App/ContentView.swift:54–56`).

A walk that stopped at the first result would leave the last two cases unresolved.

**Risk.** `lookup(_:with:)` is public. The scope conformances behind it are `@_spi(Experimental)`, for example `ExtensionDeclSyntax` at SLL/Scopes/ScopeImplementations.swift:386. Its behaviour may change between swift-syntax releases. See Q25.

### 7.3 Type names

**Where type names are read.** The library sweeps every `TypeSyntax`:

- `IdentifierTypeSyntax` (`.name`, `.genericArgumentClause`, `.moduleSelector`; N/SyntaxNodesGHI.swift:1715) and `MemberTypeSyntax` (`.baseType`, `.name`; N/SyntaxNodesJKLMN.swift:4268);
- through sugar: `ArrayTypeSyntax`, `DictionaryTypeSyntax`, `OptionalTypeSyntax`, `ImplicitlyUnwrappedOptionalTypeSyntax`;
- through wrappers: `SomeOrAnyTypeSyntax`, `CompositionTypeSyntax`, `MetatypeTypeSyntax`, `AttributedTypeSyntax`.

In expressions, a type is usually a `DeclReferenceExprSyntax`, not a `TypeExprSyntax`. A `DeclReferenceExprSyntax` is a **type-name candidate** when all of these hold:

- it is the `calledExpression` of a `FunctionCallExprSyntax`, the `base` of a `MemberAccessExprSyntax`, or the `expression` of a `GenericSpecializationExprSyntax`;
- its `baseName`, after any leading underscores, starts with an uppercase letter (so `_HeapNode` and `_UnsafeHandle` qualify);
- it is not a known module name: this module, a platform module (§7.4) or a module the file imports;
- §7.2 does not resolve it to a local, parameter or member.

A candidate is classified in this order:

1. a module type, by the resolution order below: a type;
2. a name in the platform type table (§7.4, harvested names only): a type;
3. a module free function, or a name in the platform free-function table: a **free function**, not a type;
4. a module global: a **global**, not a type;
5. `^NS[A-Z]` in a file that imports Foundation or a module known to re-export it (§7.4): a platform type;
6. anything else: an external type.

Why: an uppercase first letter does not make a type. `NSDecimalRound`, `NSLog` and `XCTAssertEqual` are functions, and uppercase constants exist. Steps 3 and 4 decide them from the tables before the `NS` pattern guesses.

Casts parse as `UnresolvedAsExprSyntax` plus `TypeExprSyntax` inside a `SequenceExprSyntax` unless SwiftOperators folds them (`P/Expressions.swift:245–249`). So visitors must not depend on `AsExprSyntax` or `IsExprSyntax`.

**Resolution order for a simple name `N`:**

1. **Module qualification.** This covers `MemberTypeSyntax`, `MemberAccessExprSyntax` and the `Module::name` selector (`ModuleSelectorSyntax`). If the root names a known module, strip it, record the module, and resolve the remainder by that module:
   - this module: resolve the remainder by steps 2–5;
   - a platform module: look the remainder up in the platform tables; found means `platform`, not found means `external`;
   - any other module: `external`, with the module recorded.
2. **Generic parameters and associated types.** If `N` names one, it is not coupling. Generic parameters come from `GenericParameterSyntax.name` (N/SyntaxNodesGHI.swift:644) in the enclosing type, function, subscript, initialiser and typealias clauses. In an extension, the extended type's clause also counts. Associated types and primary associated types of the enclosing protocol count as well. The library collects these by hand, because SwiftLexicalLookup's generic-parameter scopes are SPI. §7.2 uses the same table for `.lookForGenericParameters`.
3. **Nesting chain, innermost first:**
   - nested types and member typealiases of the current type, including those declared in its merged extensions;
   - nested types and member typealiases of its in-module superclass chain;
   - nested types and member typealiases of each enclosing type;
   - module top-level types;
   - module top-level typealiases.
   A typealias found at any level is expanded one level at a time, with a cycle guard, and the expansion is resolved from the typealias's own position. Example: `MarkedCircularBuffer.Index = CircularBuffer<Element>.Index` resolves to `CircularBuffer.Index`.
4. **Qualified names `A.B`.** Resolve `A` by steps 1–3, then find `B` among A's merged nested types and member typealiases. The target is the nested type `A.B`, not `A`. Why: `A.B` is the type the code depends on; `ceFamily` (§9.4) collapses it to `A` when that view is wanted.
5. **No module-wide simple-name fallback.** Swift does not let code name another type's nested type by its bare name unless it is inherited. So a bare `Iterator` that matches only `Other.Iterator` is counted in `unresolvedTypeRefs` and adds no edge.

Step 5 removes the main error source in the prototype. Simple-name matching there was ambiguous for 5–29% of references; in swift-collections, `Iterator` is declared 27 times and `Index` 10 times. Any reference that still matches more than one type goes to `ambiguousTypeRefs`. An ambiguous reference never becomes a guessed edge.

**In-module superclass chain.** For a class, the first inherited type is a possible superclass unless it is a known protocol (a module protocol or a protocol in the platform table). If it resolves to a module class, that class is the superclass, and the chain continues from it with a cycle guard. If it does not resolve to a module type, it is recorded as `possibleSuperclass` (§9.1) and the chain stops. Why: Swift requires the superclass to be listed first, and a known protocol is the only thing syntax can rule out.

**Outcome buckets.** A resolved name falls into one of three buckets:

- `module`: the name resolves to a type of this module.
- `platform`: the name is not declared in the module and is in the platform table (§7.4), directly or after stripping a platform-module qualifier.
- `external`: anything else. The supplying module is recorded when the name is qualified by a module, or when the file imports exactly one non-platform module. Otherwise it is unknown.

A non-platform module is any module that is not a platform module (§7.4). SwiftUI, AppKit, UIKit and Combine are non-platform. A name the module declares always shadows the platform table, so a module's own `Result` or `State` is `module`.

### 7.4 Platform table (standard library and Foundation exclusion)

The exclusion list is generated, not typed by hand. A generator tool in the library's repository builds it from three sources. The tool is an executable target, not a build plugin. Its output is committed as a resource, so every machine gets the same table.

**1. Swift interfaces.** It parses these with SwiftParser and collects the names of `public` and `open` type declarations (struct, class, enum, protocol, actor, typealias), top-level and nested, and the names of `public` top-level functions:

- `SDK/usr/lib/swift/Swift.swiftmodule/arm64e-apple-macos.swiftinterface`
- `SDK/usr/lib/swift/_Concurrency.swiftmodule/arm64e-apple-macos.swiftinterface`
- `SDK/usr/lib/swift/_StringProcessing.swiftmodule/arm64e-apple-macos.swiftinterface`
- `SDK/usr/lib/swift/Dispatch.swiftmodule/arm64e-apple-macos.swiftinterface`
- `SDK/System/Library/Frameworks/Foundation.framework/Modules/Foundation.swiftmodule/arm64e-apple-macos.swiftinterface`
- `$(xcrun --show-sdk-platform-path)/Developer/usr/lib/XCTest.swiftmodule/arm64e-apple-macos.swiftinterface`, used only in files that import XCTest.

It also collects the type each top-level extension in these interfaces extends: types imported from C or Objective-C, such as `DispatchQueue` and `XCTestCase`, appear in the interfaces only as extended types. `open` declarations are needed because `JSONDecoder` is `open class` (Foundation swiftinterface:8886). Dispatch, `_StringProcessing` and XCTest are included because every Apple toolchain ships them and Foundation re-exports Dispatch; without them `DispatchQueue` and `XCTAssertEqual` would be external names. For scale, on SDK 27.2: `grep -cE '^([@a-z][^ ]* )*public (final )?(struct|class|enum|protocol|typealias) '` counts 385, 47 and 120 top-level declarations (at column 0, after any attributes or modifiers) in the Swift, `_Concurrency` and Foundation interfaces. Without the column-0 anchor, `grep -cE 'public (final )?(struct|class|enum|protocol|typealias) '` counts 1114, 185 and 1178, nested declarations included. Both greps skip `open class` and `actor`, so the generated table is larger.

**2. Foundation API notes.** Clang-imported types renamed for Swift are not in the swiftinterface. `Decimal` is `NSDecimal` (NSDecimal.h:53) and `TimeInterval` is `typedef double NSTimeInterval` (NSDate.h:22). The tool reads the `SwiftName:` values in the `Typedefs:` and `Tags:` sections of `SDK/System/Library/Frameworks/Foundation.framework/Headers/Foundation.apinotes` (`NSDecimal` → `Decimal`, `NSTimeInterval` → `TimeInterval`) as platform type names.

**3. Foundation header functions.** The tool reads the function name from each `FOUNDATION_EXPORT` function declaration in the Foundation headers (`NSDecimalRound`, NSDecimal.h:76; `NSLog`) as a platform free-function name.

Sources 2 and 3 are line scans, not a Clang parse. The generated table is stored as a resource and versioned by SDK version. On SDK 27.2 it holds 2,892 type names (150 of them protocols), 421 free functions and 37 XCTest names. Its version is reported with every result (`MetricsVersion.platformTable`, §13.4).

**Platform modules** are the modules whose interfaces are harvested: Swift, `_Concurrency`, `_StringProcessing`, Dispatch and Foundation, plus XCTest in files that import it.

**The `NS` fallback.** Foundation's Objective-C classes come from Clang headers. In a file that imports Foundation, or a module known to re-export it (SwiftUI, AppKit, UIKit, Combine), a type-name candidate matching `^NS[A-Z]` that steps 1–4 of §7.3 did not classify is `platform`.

The same parse yields a protocol refinement table (Hashable → Equatable, RandomAccessCollection → BidirectionalCollection → Collection → Sequence) for later use.

### 7.5 Call keys

Fan-out (§8.1) and the cohesion call edges (§9.3) share one call key. For each `FunctionCallExprSyntax` (N/SyntaxNodesEF.swift:3015):

1. **Unwrap the callee.** Strip `GenericSpecializationExprSyntax.expression`, `OptionalChainingExprSyntax.expression` and `ForceUnwrapExprSyntax.expression`.
2. **Strip a module qualifier.** If the callee is `M.f` or `M::f` and `M` is a known module (§7.3), record `M` and classify `f` as an unqualified callee. Example: Heap's `max` getter calls `Swift.max(buffer[1], buffer[2])`, which becomes `free.max(_:_:)`.
3. **Receiver kind.** The first kind that applies:
   - **`self`:** the base is `self`, or the callee is unqualified and §7.2 resolves it to an own or inherited member.
   - **`super`:** the base is a `SuperExprSyntax`.
   - **`T`:** the callee or its base is a type name (§7.3), qualified or not, or the callee is unqualified and §7.2 resolves it to a static of the current type or of an enclosing type. The key carries the resolved type path (for a bare static, the path of the type that declares it), or the spelled name for an external type. `T(...)`, `Self(...)` and `T.init(...)` are keyed `T.init`.
   - **`free`:** the callee is unqualified and is a module free function (§7.2 step 5), or its name is in the platform free-function table, or it is a type-name candidate that §7.3 classified as a free function.
   - **`implicit`:** any other unqualified callee. It may be a member inherited from outside the module, a protocol default, a macro-added member or a free function from a non-platform module. Why a separate kind: syntax cannot tell a protocol default from an imported free function, so neither `self` nor `free` would be true.
   - **`.`:** an implicit member, meaning a `MemberAccessExprSyntax` with `base == nil` (`.alert(...)`, `.currency(code:)`).
   - **`chain`:** the base is a call result. After stripping `OptionalChainingExprSyntax`, `ForceUnwrapExprSyntax`, `TryExprSyntax`, `AwaitExprSyntax`, `UnsafeExprSyntax` and one-element parentheses, the base is a `FunctionCallExprSyntax` (`Date().timeIntervalSince(x)`, a SwiftUI modifier chain).
   - **`?`:** any other expression receiver. v1 does not type local receivers (see §11.1).
4. **Labels.** From `.arguments` → `LabeledExprSyntax.label` (`_` when absent). Add `_` for `.trailingClosure`, and the label for each `.additionalTrailingClosures` element.
5. **Key** = receiver kind + type path (for `T`) + base name + labels. Examples: `self.touch()`, `?.append(_:)`, `Date.init()`, `free.max(_:_:)`, `implicit.summary()`, `..currency(code:)`, `chain.timeIntervalSince(_:)`. A `chain` key does not include the base call, which is counted on its own.

---

## 8. v1 function-level metrics

Function-level values attach to each PRD §6.1a function record. Closures fold into the enclosing function. A nested function is its own function and is excluded from its parent (§2.1). Default-argument expressions are not walked, because they run at the call site. Stored-property initialisers belong to the type (§9.4), not to any function, so a `.propertyInitializer` record has no function-level coupling (§2.1). Local computed and observed variables are their own functions, like nested functions.

All values in this section are final only after the module pass (§7.1, §13). The `self`/`implicit` split needs members that may live in other files, `T` keys carry resolved type paths, the diagnostic exclusion checks module declarations, and the closure-parameter test expands module typealiases.

`try`, `await` and `unsafe` (`TryExprSyntax`, N/SyntaxNodesTUVWXYZ.swift:693; `AwaitExprSyntax`, N/SyntaxNodesAB.swift:4901; `UnsafeExprSyntax`, N/SyntaxNodesTUVWXYZ.swift:3035) are walked through. `unsafe` is used throughout swift-collections.

### 8.1 `fanOut`: distinct callees

- **Level:** function.
- **Definition:** `fanOut` is the number of distinct call keys (§7.5) in the function's body, excluding keys with receiver `.` and `chain`. Those are counted separately:
  - `fanOutImplicitMember`: distinct keys with receiver `.`. Why separate: an implicit member is usually an enum case or a static factory of the contextual type, and syntax cannot tell which. In a TCA reducer they are most of the calls (§12.7).
  - `fanOutChained`: distinct keys with receiver `chain`. Why separate: the receiver's type is unknown, and most chains are modifiers on a value just built (seven SwiftUI modifiers in one SwiftProjectLint getter, §12.7). They name no new collaborator.
- **Syntax read:**
  - `FunctionDeclSyntax.body`, `InitializerDeclSyntax.body`, `DeinitializerDeclSyntax.body`, `AccessorDeclSyntax.body`, `SubscriptDeclSyntax.accessorBlock` and the `.getter` case of `AccessorBlockSyntax.accessors`;
  - `FunctionCallExprSyntax.calledExpression`, `.arguments`, `.trailingClosure`, `.additionalTrailingClosures`.
- **Exclusions:**
  - calls of a local, a parameter or a nested function, for all of which lookup returns `.fromScope`. Calls of a local or a parameter are closure calls. A nested function is its own record (§2.1), so calling it adds no dependency to the parent's design;
  - pattern-position calls: a `FunctionCallExprSyntax` with an `ExpressionPatternSyntax` ancestor (N/SyntaxNodesEF.swift:1629). `case .foo(let x):` and `guard case .some(.edit(let e))` parse as calls. Why: they test a value; they call nothing. A real call inside an expression pattern (`case f():`) is lost, which is rare;
  - operators: operator tokens are not calls. Their operands are walked, so `Date().timeIntervalSince(d) > interval` still yields its calls;
  - subscripts (`SubscriptCallExprSyntax`);
  - macro expansions (`MacroExpansionExprSyntax`), which are counted in `macroExpansionCount` instead. Calls in their arguments are walked like any other code (§2.7);
  - the default list of free diagnostic functions (`MetricsOptions.diagnosticFreeFunctions`, §13.1), when the module does not declare them: `assert`, `assertionFailure`, `precondition`, `preconditionFailure`, `fatalError`, `print`, `debugPrint`, `dump`. These create no design dependency.
- **Also reported:** `byReceiver` (distinct keys per receiver kind, all eight kinds; a field of `FanOut`, §13.2) and `distinctBaseNames`.
- **Known error modes:**
  - *Overcount:* defaulted or variadic parameters split one callee into several keys (`assert(_:)` and `assert(_:_:)`). Trailing-closure labels are guessed.
  - *Undercount:* overloads that differ only by parameter type merge. `?` receivers merge (`a.append(x)` and `b.append(x)` are one key). `chain` receivers merge by name.
  - *Not seen:* computed-property reads, observers, string interpolation and implicit conversions are hidden calls.
  - The spot checks in the feasibility study found syntactic call-key sets 4–6% high against true callee sets on swift-collections `Heap`, swift-nio `MarkedCircularBuffer` and SwiftStats `SitrepFileVisitor`. They were measured before the pattern, implicit-member and chained splits.
- **Used for:**
  - SwiftStats: per-function census and distribution, a candidate input to a coupling-weighted hotspot, and the approximate static-dependency side of hidden coupling before M7.
  - SwiftProjectLint: no current rule. A future "high fan-out" threshold would read `fanOut`.
- **Not provided:** fan-in. Name-inverted fan-in is badly ambiguous for `init`, `append` and `index`. It belongs to the index. Henry–Kafura's (fan-in × fan-out)² is not stored either [HK81].

### 8.2 Common coupling: globals, statics, singletons

- **Level:** function.
- **Definitions** (distinct names per function):
  - `globalRefs`: module globals referenced. These are unqualified names that §7.2 step 4 resolves, type-name candidates that §7.3 classifies as globals, or `ThisModule.x`.
  - `mutableGlobalRefs`: the subset declared as a stored `var`, including `nonisolated(unsafe) var`.
  - `staticRefs`: static *property* references to module types:
    - a `MemberAccessExprSyntax` that is not a call's callee, whose base is a type name resolving to a module type (or `Self`), and whose member is declared `static`/`class` in that type;
    - a bare name that §7.2 resolves to a static of the type or of an enclosing type.
  - `mutableStaticRefs`: the subset whose declaration is a stored `static var`.
  - `singletonRefs`: static references to a singleton. A member is a singleton when either:
    - the module declares it in a class or actor `T` as a stored `static let` or `static var` (no accessor block), initialised by `T(...)`, `Self(...)` or `.init(...)`; or
    - for a type not declared in the module, its name is one of `shared`, `default`, `standard`, `current` or `main`.
    Why: a singleton is one stored instance with identity. A computed `static var root: Self` (swift-collections `_HeapNode.root`, `~/GitHub_projects/swift-collections/Sources/HeapModule/_HeapNode.swift:84`) returns a fresh value each time, and a struct instance has no identity. A type annotation alone is not enough.
- **Exclusions:**
  - enum cases: a member matching an `EnumCaseElementSyntax.name` (N/SyntaxNodesEF.swift:586) of the target type;
  - `.self`, `.init`, `.Type`, `.Protocol`;
  - external `X.y` other than the singleton list, because syntax cannot tell an external enum case from a static property.
- **Known error modes:**
  - An implicit-member singleton (`let x: Foo = .shared`) is not seen.
  - External names on the singleton list can be enum cases (`.default`).
  - Writes are not separated from reads in v1 (§11.1).
- **Used for:**
  - SwiftStats: a census of common coupling.
  - SwiftProjectLint: `singletonUsage` (SPL/Architecture/Visitors/SingletonUsageVisitor.swift:33–83) stays a per-site rule with its service-suffix policy. This census is deliberately broader.

### 8.3 Parameter counts (data coupling)

- **Level:** function.
- **Definitions** for `func`, `init` and `subscript`. A subscript's counts go on its `.subscriptGetter` record or, when it has explicit accessors, on its first accessor record in source order, so each declaration is counted once (Q1). Other records have `parameters = nil`:
  - `parameterCount`;
  - `defaultedParameterCount` (`.defaultValue != nil`);
  - `variadicParameterCount` (`.ellipsis`);
  - `inoutParameterCount`;
  - `closureParameterCount` and `escapingClosureParameterCount`.
- **Syntax read:**
  - `FunctionParameterClauseSyntax.parameters` → `FunctionParameterSyntax` (N/SyntaxNodesEF.swift:3995).
  - **inout:** `.type` is an `AttributedTypeSyntax` whose `.specifiers` contain a `SimpleTypeSpecifierSyntax` with the `inout` keyword.
  - **closure:** strip `AttributedTypeSyntax`, `OptionalTypeSyntax` and a one-element tuple, and expand module typealiases (module pass). A closure parameter is one that leaves a `FunctionTypeSyntax`. It is escaping if it has `@escaping` or is optional, since optional closures escape implicitly.
- **Known error modes:** a closure behind an imported typealias is missed. Otherwise exact.
- **Used for:**
  - SwiftStats parameter count (PRD §7.2, [PRD]:141).
  - SwiftLint's `function_parameter_count` can be derived as `parameterCount − defaultedParameterCount` on `func` records without `override`. Its default `ignores_default_parameters` is true (`~/GitHub_projects/SwiftLint/Source/SwiftLintBuiltInRules/Rules/RuleConfigurations/FunctionParameterCountConfiguration.swift:6–8`). No SwiftProjectLint rule should repeat it.


---

## 9. v1 type-level metrics

Every value in this section needs the module pass, because a type's members can be spread across files.

### 9.1 Type record and sizes

- **Level:** type (every type and extension group).
- **Fields:**
  - `kind`, `typeKey`, and the files and extensions that contribute (each extension with its file, conformances and `where` clause).
  - **`nom`:** the number of members (§2.3), with `#if` duplicates merged. It is partitioned into `instanceMembers` + `staticMembers` = `nom`; `init` and `deinit` count as instance members. Beside the partition, and overlapping it, it reports `initialisers`, `computedProperties` and `subscripts`. These three do not sum to `nom`.
  - **`noa`:** the number of the type's own stored instance properties.
  - `storedProperties`: one fact per property with `name`, `isLet`, `isLazy`, `isWeakOrUnowned`, `hasObservers`, `attributeNames`, `typeText`.
  - `caseCount` for enums.
  - `customAttributes` on the declaration.
  - `hasKnownAttachedMacro`: true when the type or a member carries `@Observable`, `@ObservableState`, `@Reducer`, `@Model`, `@DependencyClient`, `@CasePathable`, or an attribute named after a `MacroDeclSyntax` declared in the scanned modules.
  - `conformances`: declared names from the declaration and all extensions. For a class, the superclass or `possibleSuperclass` (§7.3) is not a conformance. `P & Q` is split. `~Copyable` is dropped. `@unchecked`, `@retroactive` and `@preconcurrency` are unwrapped. Conditional conformances are flagged.
  - `superclass` (a module class) or `possibleSuperclass` (an unresolved first inherited name of a class). A consumer that tests for a conformance outside the platform table, such as `ObservableObject` from Combine, checks both `conformances` and `possibleSuperclass`.
- **Protocol types add:**
  - **`nom`** for a protocol counts its requirements that §2.3 would call members: `func`, `init`, `subscript` and property requirements, including inside `#if` clauses. Associated types and extension members are not counted. Why: NOM is what a conformer must provide; defaults are counted below.
  - **`requirementCount`:** `FunctionDeclSyntax`, `VariableDeclSyntax`, `InitializerDeclSyntax`, `SubscriptDeclSyntax` and `AssociatedTypeDeclSyntax` in `memberBlock`, *including inside `#if` clauses*.
  - **`defaultImplementationCount`:** members of the protocol's extensions, split into `defaultsForRequirements` (base name and labels match a requirement) and `extensionOnlyMembers`.
- **Why:** every other type metric needs this record. Size confounds coupling and cohesion metrics [ElEmam01], so NOM and NOA are always reported next to them.
- **Used for:** SwiftStats type member counts (PRD §7.2). SwiftProjectLint `fatProtocol`, `godViewModel`, `fatViewDetection` and `tooManyEnvironmentObjects` (§14.4).

### 9.2 `wmcCognitive`, `wmcDecisions`

- **Level:** type.
- **Definition:** the sum of Part A's per-function cognitive complexity (and, separately, decision count). It runs over every PRD §6.1a function record of the merged type. That includes init, deinit, static members, accessors, observers, excluded witnesses, nested functions, and local computed and observed variables, each nested or local function as its own term. It excludes `.propertyInitializer` records (§2.1) and the functions of nested and local types.
  - When a member has `#if` variants, take the larger value. One build compiles one variant, and summing would double a type with `#if os(Linux) … #else … #endif`.
- **Protocol types:** WMC is the sum over the default implementations, and is labelled `wmcDefaults`.
- **Source:** Chidamber & Kemerer's WMC = Σ cᵢ, with the weight left open [CK94]. Inherited methods are excluded, so protocol defaults never count towards a conformer.
- **Known error modes:** those of the complexity metrics, plus invisible macro members.
- **Used for:** SwiftStats per-type census (PRD §7.2). The WMC input to a Lanza–Marinescu God Class rule [LM06].

### 9.3 `lcom4`: cohesion as connected member groups

- **Level:** type (struct, class, actor). It is null for enums, protocols and extension groups.
- **Source:** Hitz & Montazeri 1995 [HM95]. Chosen over LCOM1/2 and LCOM* for these reasons [HM96]:
  - its value means "N disconnected groups";
  - it can list the groups;
  - adding a cohesive member never raises it.

**Attributes A.** The type's stored instance properties (§2.4), plus, for a class, the stored instance properties of its in-module superclass chain (§7.3). `attributeCount` = |A|. It equals NOA except for subclasses of module classes. Why: a subclass's methods use the state they inherit. Without this, swift-nio `ServerSocketChannel` splits on state that lives in `BaseSocketChannel` (§12.7).

**Nodes M.** Instance members that have bodies:

- `func`, instance subscripts, and computed properties (one node per property, all accessors merged);
- overloads are separate nodes, keyed by the PRD §6.1 key;
- `#if` variants are merged;
- members of the superclass are not nodes.

These are left out of M and listed in `excludedMembers`, each with a reason:

| Excluded | Reason |
|---|---|
| `init`, `deinit` | Definite initialisation makes every struct `init` touch every attribute, which would glue every type together. Bieman & Kang [BK95] and Aivosto [HM95] exclude them too. |
| `static` / `class` members | They cannot touch instance state. |
| `willSet` / `didSet` | They belong to their stored property. |
| `hash(into:)`, `hashValue`, `encode(to:)` | Whole-value witnesses read every field, like a synthesised conformance ([SE-0185], [SE-0166]). Hand-written and synthesised versions must give the same value. `==` and `init(from:)` are already excluded as static and init. |
| `description`, `debugDescription`, `customMirror` | They usually print every field. On by default; an option turns it off (Q21). |

`nonisolated` members stay in M. The witness rows above apply to them as to any member. `unownedExecutor` is not excluded: it reads one attribute, like any accessor (GRDB `DispatchQueueActor.unownedExecutor` reads `executor`, `~/GitHub_projects/GRDB.swift/GRDB/Core/DispatchQueueActor.swift:18–20`).

**Accesses (member m touches attribute a).** The library walks m's bodies, including closures and nested functions. It skips nested and local type declarations.

1. `self.a` or `self?.a` (`MemberAccessExprSyntax.base` is `self`, `.declName.baseName` is `a`), or `super.a` for an inherited attribute.
2. A bare `a` that §7.2 resolves to an own or inherited stored property.
3. Shorthand binding `if let a` / `guard let a` [SE-0345]: an `OptionalBindingConditionSyntax` (N/SyntaxNodesOP.swift:531) with `.initializer == nil` and an `IdentifierPatternSyntax` named `a`. Run the §7.2 walk at the condition. The prototype missed this case, for example in GRDB `Database.interrupt()` (`~/GitHub_projects/GRDB.swift/GRDB/Core/Database.swift:1165`).
4. Property-wrapper names [SE-0258]: a `$a` or `_a` that reaches member lookup and is not itself declared is checked again as `a`.
5. A key path whose root is `Self` or the type's own name, and whose first component is a `KeyPathPropertyComponentSyntax` with `.declName.baseName == a` (N/SyntaxNodesJKLMN.swift:783). A key path with no root is not counted. Its first component name is listed in `rootlessKeyPathNames` when it matches an attribute. Why: an absent root is inferred and often not `Self`; in `items.map(\.price)` it is `Item`.
6. **Whole `self` in a struct.** A `self` `DeclReferenceExprSyntax` counts as touching every attribute unless it is the base of a member access, the base of a subscript call, the callee of a call, or inside a closure capture clause (`ClosureCaptureClauseSyntax`, N/SyntaxNodesC.swift:1196). That covers arguments, return values, initialiser values, operator operands (`self == other`), `switch self`, the target of `self = …`, and `&self`. Value semantics copy all stored state. The rule does not apply to classes or actors, where passing `self` passes identity. Enums have no attributes, so the rule has nothing to add for them.

**Member–member edges.**

- A call whose key (§7.5) has receiver `self` and matches own nodes connects to them. Nodes match when base name and labels are equal. If none match the labels, it connects to every own node with that base name.
- A call to an overload of the caller's own name is never dropped. The prototype's first version dropped such calls and broke delegating overloads, for example `~/GitHub_projects/swift-collections/Sources/BitCollections/BitSet/BitSet+SetAlgebra symmetricDifference.swift:54–55` and `:88–95`, and `~/GitHub_projects/swift-nio/Sources/NIOCore/ByteBuffer-aux.swift:894`.
- Reading an own computed property connects to its node.
- `self[...]` (`SubscriptCallExprSyntax`, N/SyntaxNodesQRS.swift:2908) connects to the own subscript nodes.
- A method reference used as a value (`self.f`, or bare `f` resolving to an own method) connects to it.
- Calls to inherited members add no edge. Their names are listed in `inheritedMemberRefs`.

**Identical-label overloads.** Labels fix the argument count, but not the argument types. Overloads with the same base name and labels are all joined by one call to any of them. Examples: every `visit(_:)` in a `SyntaxVisitor` subclass, and the two `bind0(to:promise:)` in swift-nio `ServerSocketChannel` (`~/GitHub_projects/swift-nio/Sources/NIOPosix/SocketChannel.swift`). This is documented, not fixed: argument types are rarely visible in syntax, and guessing them would add errors of its own.

**Computation.**

1. Build an undirected graph on M. Two nodes are joined if they touch a common attribute, or if either one calls or reads the other.
2. Find the connected components.
3. A component in which no node touches an attribute is **attribute-free**. Its nodes go to `isolatedMembers`, and the component is not counted.
4. `lcom4` = the number of remaining components.

**Bound.** After step 3, `lcom4` ≤ |A|. Each counted component touches at least one attribute, and two components that touch the same attribute are one component. So a type with |A| = 1 can only score 1 or null (swift-collections `Heap` and `Heap._UnsafeHandle`, GRDB `DispatchQueueActor`), and a type with |A| = 2 at most 2. Corpus figures for "LCOM4 > 1" are therefore reported over types with |A| ≥ 2, the only types where it can happen. For types other than subclasses of module classes, |A| = NOA, so this is NOA ≥ 2.

**Null cases.** `lcom4` is null, never 0 (PRD §6.5), with one reason. When several conditions hold, the first in this table wins:

| Reason | Condition |
|---|---|
| `notApplicableKind` | enum, protocol or extension group |
| `noStoredProperties` | \|A\| = 0 |
| `fewerThanTwoMembers` | \|M\| < 2 |
| `noStateUse` | every component is attribute-free |

Why this order: each reason is checked from the cheapest fact to the one that needs the graph, so the reason names the most basic cause.

**Also reported:**

- `components`: for each component, its member keys, the attributes it touches, and the extensions (file and conformances) its members are declared in. A reader then sees "this group is the `CustomStringConvertible` conformance", not just "split this type".
- `isolatedMembers`, `excludedMembers`.
- `unusedAttributes`: the type's own attributes that no node touches. They may still be used by an initialiser or an excluded witness. Inherited attributes are not listed.
- `unresolvedMemberRefs`: bare or `self.` names that reach member lookup but are not declared in the type or its in-module superclass chain, with the names listed.
- `inheritedMemberRefs`, `rootlessKeyPathNames`.
- `nodeCount` (|M|), `noa` and `attributeCount` (|A|).

**Why drop attribute-free components.** Aivosto's convention already drops empty methods from LCOM4. Members that reach no state carry no cohesion information: they forward to free functions, call protocol defaults, or return constants. The prototype measured the share of types with LCOM4 > 1 under each rule. Its denominator was all in-domain types, not types with |A| ≥ 2, and it used a first-result lookup, so these figures are indicative:

| Corpus | first version | + overload fix | + whole-`self` | + drop attribute-free |
|---|---|---|---|---|
| swift-collections | 44.5% | 40.6% | 26.6% | 3.1% |
| swift-nio | 32.2% | 25.0% | 19.6% | 3.3% |
| GRDB | 44.1% | 42.7% | 30.1% | 4.9% |
| TCA | 43.9% | 40.2% | 30.5% | 3.7% |
| SwiftProjectLint | 14.2% | 13.2% | 9.1% | 1.4% |

Part of the last drop is the bound, not better judgement. At the median NOA of 2 (§11.2), LCOM4 cannot exceed 2. The library's corpus tests report the share over types with |A| ≥ 2.

The draft of Part B named three remaining worst cases as real findings. Two were not: swift-nio `ServerSocketChannel` split on superclass state, and SwiftStats `FunctionCollector` scores 1, not 3 (§12.7). GRDB `Database` (169 members, 23 attributes) has not been rechecked. Null is the common answer: 32–75% of non-protocol types are out of domain (enums, data-only structs, closure clients).

**Known error modes:**

- Calls to protocol defaults and to members inherited from outside the module are not nodes, so their edges are lost (`formIndex(after:)` at `~/GitHub_projects/swift-nio/Sources/NIOCore/MarkedCircularBuffer.swift:169`). They are counted in `unresolvedMemberRefs`.
- Identical-label overloads are joined (above).
- A local wrapped variable shadowing a member, such as a local `@Bindable var viewModel`, maps `$viewModel` to the member. Lookup returns `.lookForMembers` for `$viewModel`, because no scope introduces that name (`~/xcode_projects/SwiftProjectLint/Sources/App/ContentView.swift:62, 67, 78`). It is harmless there, because the local copies the member.
- Macro-generated members and storage are invisible.
- `#if` union can join groups that never coexist in one build.
- The value is sensitive to definitions more than to syntax error. On SwiftStats `SitrepFileVisitor` the true value is 2. Including the empty `init` and `deinit` gives 4. Counting the static `facts` gives 1.

**Used for:**

- SwiftStats: per-type census. A "split candidate" signal (LCOM4 ≥ 2 with each counted component at least k members) lists the components.
- SwiftProjectLint: a possible new rule, `lowCohesionType`. Fire when LCOM4 ≥ 2 and each counted component has ≥ 3 members. Skip types with `hasKnownAttachedMacro`.

### 9.4 `ce`: outgoing type coupling (syntactic CBO, efferent half)

- **Level:** type.
- **Definition:** the number of distinct module types (§7.3, `module` bucket) that the type names, outside its own nesting family (§2.2). "Names" covers:
  - its declaration and inheritance clause;
  - generic constraints on the type itself (`struct Box<T: Shape>`, `GenericParameterSyntax.inheritedType`), and `where` clauses on the type and on its extensions;
  - for a protocol, its `associatedtype` constraints (inheritance clause and `where` clause);
  - its merged extensions' inheritance clauses;
  - stored property annotations and initialisers;
  - enum case payload types (`EnumCaseParameterSyntax.type`, N/SyntaxNodesEF.swift:963);
  - member typealias targets (`TypeAliasDeclSyntax` in the member block);
  - member signatures: parameter, return and `throws` types, and the member's own generic constraints (`GenericParameterSyntax.inheritedType`, `GenericWhereClauseSyntax` requirements);
  - custom attributes on stored properties that resolve to a module type (property wrappers);
  - member bodies, including nested functions: every `TypeSyntax` and every type-name candidate classified as a type.
- **Target.** `A.B` targets the nested type `A.B` (§7.3 step 4).
- **Split.** Every target falls into exactly one of these, checked in this order, so `ce` = `ceProtocol` + `ceView` + `ceNamespace` + `ceConcrete`:
  - `ceProtocol`: the target is a protocol.
  - `ceView`: the target's conformances include `View`, directly or through an in-module protocol that refines it, and the module declares no `View` of its own. Why: composing child views is how SwiftUI builds a screen. Counted with the rest, they hide a view's model and service dependencies (seven of eleven targets in SwiftProjectLint `ContentView`, §12.7).
  - `ceNamespace`: the target is an enum with no `case` declarations whose members are all `static` or `class` (nested types allowed). Why: such a type is a namespace for free functions. Depending on it is like calling free functions.
  - `ceConcrete`: everything else.
- **`ceFamily`.** The union of the targets of the type and every type nested in it, at any depth, with each target collapsed to its outermost enclosing type. Its own family is excluded. Why: in TCA and SwiftUI code the coupling of a feature lives in its nested `State`, `Action` and `Destination` types, which `ce` of the outer type does not see (§12.7).
- **Edge kinds.** Each edge records the set of kinds that produced it:
  - `inheritance`: superclass that resolves to a module class;
  - `conformance`: a non-protocol type to a protocol;
  - `refinement`: a protocol to a protocol it inherits (`protocol Sub: Base`);
  - `storedProperty`. `TypeCoupling.isWeakOrUnowned` is true only when every stored property that contributes the `storedProperty` kind to the edge is `weak` or `unowned`. One strong stored property makes it false, and it is false on an edge without the `storedProperty` kind;
  - `casePayload`;
  - `typealias`;
  - `signature`: a member's parameter, return or `throws` type, or the member's own generic constraint;
  - `constraint`: a generic constraint on the type itself, a `where` clause on the type or one of its extensions, or a protocol's `associatedtype` constraint;
  - `wrapper`;
  - `body`.
- **Exclusions:**
  - the type itself and `Self`;
  - every type in its own nesting family, parent or child, counted as `internalRefs`. Why: a nested type is part of its parent's design, and counting only child-to-parent references would be asymmetric;
  - generic parameters and associated types;
  - module names;
  - built-in attributes (lowercase, or on the compiler's attribute list);
  - everything in the `platform` and `external` buckets.
- **Also reported:**
  - `internalRefs`.
  - `externalNameCount`: distinct names in the `external` bucket. It is labelled a lower bound.
  - `platformNameCount`: distinct names in the `platform` bucket. Sugar counts as its type (`[T]` as `Array`, `T?` as `Optional`).
  - `unresolvedTypeRefs`, `ambiguousTypeRefs`.
- **Why module-local:** module-bucket coupling was exact in 3 of 3 feasibility spot checks. The `platform` bucket was 7–17% low. External names were about 37% low (12 of 19 on `SitrepFileVisitor`), with 100% precision. The misses are inferred types (`let x = make()`, closure parameters, implicit `.member`, member chains). Cross-module coupling is index work.
- **Known error modes:**
  - a bare associated-type name (`Element`, `Index`) inside a conformer, when the module also declares a top-level type of that name, creates a false edge;
  - an uppercase free function or constant from a non-platform module (`CGRectMake`) is taken for an external type; it adds to `externalNameCount`, never to `ce`;
  - macro-generated references are invisible, so a reference to a macro-generated nested type is unresolved.
- **Used for:**
  - SwiftStats: per-type coupling census (PRD §7.6 line 172, syntactic provenance).
  - SwiftProjectLint: `circularDependency`, plus `concreteTypeUsage`, `layerDependency` and `architecturalBoundary` as consumers of the shared extractor (§14.4).

### 9.5 `caWithinModule` and `conformerCount`

- **Level:** type.
- **Definition:**
  - `caWithinModule`: the number of distinct module types with a `ce` edge to this type, from the same graph inverted.
  - For protocols, `conformerCount`: the number of non-protocol module types whose resolved declared conformances (`TypeResult.conformances`, from the declaration and every extension, §9.1) include this protocol, or an in-module protocol that refines it, directly or transitively. Conforming to `Sub` where `protocol Sub: Base` credits both `Sub` and `Base`. A refining protocol is not itself a conformer. Typealias compositions are expanded. It is defined from conformances, not from `conformance` edges, so a conformer in the protocol's own nesting family counts, although its reference is an `internalRefs` entry and not an edge.
  - `conformerCount` is per module. A rule that needs conformers from other modules, such as test doubles, joins `TypeResult.conformances` across modules (§14.4).
- **Known error modes:** the same as `ce`. References from other modules are not seen, so a public type's Ca is a lower bound. Provenance is `syntax` and resolution is approximate. The index replaces it at M7.
- **Used for:**
  - SwiftStats: type-level instability within a module.
  - SwiftProjectLint: `singleImplementationProtocol`, which joins `TypeResult.conformances` across every analysed module, test modules included, rather than reading `conformerCount` alone (§14.4). Its exemptions stay in the rule.

---

## 10. v1 module-level metrics

### 10.1 Import facts

- **Level:** file, rolled up to module.
- **Syntax read:** `ImportDeclSyntax` (N/SyntaxNodesGHI.swift:2939):
  - `.attributes`: `@_exported`, `@testable`, `@preconcurrency`, `@_implementationOnly`;
  - `.modifiers`: access-level imports;
  - `.importKindSpecifier`: scoped imports;
  - `.path.first?.name`: the module.
  - The enclosing `IfConfigClauseSyntax.condition` is kept, for example `#if canImport(X)`.
- **Module edges.** `PackageAnalysis.moduleEdges` has one `ModuleDependency` per `import` declaration in the scanned modules: `source` is the importing module, `target` the imported module, `viaExported` is true when the import is `@_exported`, `condition` is the enclosing `#if` condition (nil outside any `#if`), and `provenance` is `.import`. A module imported from several files gives several edges; a consumer that wants one edge per module pair deduplicates them.
- **Used for:** SwiftProjectLint `undeclaredTargetDependency` and `unusedTargetDependency` could read these facts. SwiftStats module structure.

### 10.2 `ceAll`, `cePackage`, `ceWithReexports`, `ca`, `instability`

- **Level:** module.
- **Definitions:**
  - `ceAll`: distinct imported modules across the module's files. The module itself and the implicit `Swift`, `_Concurrency` and `_StringProcessing` are excluded.
  - `cePackage`: the subset that are scanned modules.
  - `ceWithReexports`: `cePackage` plus the scanned modules that modules in `cePackage` re-export with `@_exported`, followed transitively. For example, `NIO` re-exports `NIOCore`, `NIOEmbedded` and `NIOPosix` (`~/GitHub_projects/swift-nio/Sources/NIO/Exports.swift:14–16`).
  - `ca`: the number of scanned *non-test* modules that import this module directly.
  - `caWithReexports`: the number of scanned non-test modules that import this module directly or import a module that re-exports it, transitively. Why: it mirrors `ceWithReexports`, so both directions of a re-export edge are visible.
  - `caTests`: the `ca` count for test modules, reported separately.
  - `instability` = `cePackage / (ca + cePackage)`. It is null when both are 0.
- **Source:** [Martin94]; [Martin02], ch. 20. Martin counts classes. The module form here is coarser but exact within the scanned packages.
- **Known error modes:**
  - dependents outside the scanned packages are unknowable;
  - transitive visibility without MemberImportVisibility is not modelled;
  - `#if canImport` makes edges configuration-dependent; the condition is recorded.
- **Used for:** SwiftStats PRD §7.6 line 173, at T0.

### 10.3 Type graph and cycles

- **Level:** module.
- **Definition:** the module's `ce` edges (§9.4) as a graph. The module result lists its strongly connected components of size ≥ 2 (`typeCycles`), with each edge's kinds and flags in `typeEdges`. `typeCycles` is computed over all edges, whatever their kinds. A rule that needs a narrower graph recomputes the components from `typeEdges`; it cannot filter `typeCycles`, because removing edges can split a component. `circularDependency` (§14.4) does this over non-weak `storedProperty` edges to non-protocol targets.
- **Module import cycles are not computed.** SwiftPM rejects cyclic target dependencies.
- **Known error modes:** the same as `ce`. Exact cycles are M7.
- **Used for:**
  - SwiftStats PRD §7.6 line 175, approximate.
  - SwiftProjectLint `circularDependency` as a query over this graph (§14.4).

---

## 11. Later set and excluded metrics

### 11.1 Later (each needs one more piece of machinery)

| Metric | Level | What it adds | Main obstacle |
|---|---|---|---|
| Typed call keys | function | Receiver type for locals that are annotated, initialised by `T(...)` or a literal, or set to `self.p` | About half of local bindings stay untyped (feasibility grep: typed by rule 38–49%) |
| Global and static writes | function | Writes split from reads: the target of `=` or a compound assignment in a `SequenceExprSyntax`, and `&x` (`InOutExprSyntax`) | Mutating method calls cannot be seen |
| Distinct constructed types per body | function | Backs `directInstantiation`'s composition-root test | None; it is low priority |
| Foreign members accessed per receiver (ATFD-like) | function | Backs `wideReachThrough` | Needs the Demeter exemption policy kept in SwiftProjectLint |
| Raw `maxMemberChainDepth` | function | An unfiltered chain length | Must not be confused with the Demeter finding |
| Generic signature counts | function, type | Generic parameters, nesting depth, `where` requirements | None; it backs `nestedGenericComplexity` |
| Isolation-crossing calls (`await other.f()`) | function | Actor coupling | Needs receiver typing to be reliable |
| TCC / LCC [BK95] | type | A normalised cohesion value | Saturates at 1.0 once whole-`self` is counted (prototype median 1.0 in every corpus) |
| DIT_module / NOC | type | Class inheritance within the module, with `externalBase` (an `override` modifier or `super.init` marks an external superclass) | Classes are a minority of Swift types; external base depth is unknown |
| Cross-module Ca within the scanned package | type | Ca from other scanned modules | Attributing a name when several modules are imported |
| Martin's A and D | module | Abstractness and distance from the main sequence | "Abstract" maps badly onto protocol-oriented Swift; experimental at most |
| Control-flag parameter count | function | Census version of `booleanControlCoupling` | Heuristic |

### 11.2 Not planned

- **RFC.** Syntax cannot bind calls to declarations, and RFC is dominated by size. Fan-out covers the useful part.
- **LCOM1, LCOM2 and LCOM\*.** They are unnormalised or unstable at Swift's median of 2 attributes, and they give no groups. In the prototype, 2–13 types per corpus had LCOM\* above 1.
- **Henry–Kafura information-flow complexity.** It needs data flow analysis, and its squared product is heavy-tailed.
- **Content, external and stamp coupling.** Content coupling is almost impossible in safe Swift. External coupling is invisible to syntax. Stamp coupling is idiomatic with value types [SMC74].
- **Law of Demeter as a library metric.** SwiftProjectLint's tuned filter already does this (SPL/Architecture/Visitors/DemeterChainFilter.swift). A second implementation would drift from it.

---

## 12. Worked examples: coupling and cohesion

All examples assume one module per example, and that each file imports Foundation. Complexity values come from Part A. WMC is shown as a sum of per-function values, then as a number. In fan-out lists, "headline" is `fanOut`; the separate counts follow it.

### 12.1 An extension in another file

```swift
// Shop/Item.swift
struct Item { let name: String; let price: Decimal }

// Shop/Inventory.swift
struct Inventory {
    private(set) var items: [Item] = []
    var lastUpdated: Date?

    mutating func add(_ item: Item) {
        items.append(item)
        touch()
    }
    mutating func touch() {
        lastUpdated = Date()
    }
}

// Shop/Inventory+Reporting.swift
extension Inventory: CustomStringConvertible {
    var totalPrice: Decimal {
        items.reduce(0) { $0 + $1.price }
    }
    var description: String {
        "Inventory(\(items.count) items, \(totalPrice))"
    }
    func isStale(after interval: TimeInterval) -> Bool {
        guard let lastUpdated else { return true }
        return Date().timeIntervalSince(lastUpdated) > interval
    }
}
```

**Merge.** The extension's `extendedType` is `IdentifierTypeSyntax` `Inventory`. It resolves to the top-level `Shop.Inventory`, so all five members join one type.

**Sizes.**

- NOA = 2 (`items`, `lastUpdated`). |A| = 2.
- NOM = 5 (`add`, `touch`, `totalPrice`, `description`, `isStale`): `instanceMembers` 5, `staticMembers` 0, `computedProperties` 2. The memberwise initialiser is synthesised, so it is not counted.

**WMC.** `cc(add) + cc(touch) + cc(totalPrice.get) + cc(description.get) + cc(isStale)`. The only increment is the `guard` in `isStale` (Part A row 16), so `wmcCognitive` = 1. The same `guard` is the only decision, so `wmcDecisions` = 1.

**LCOM4, step by step:**

1. M = {`add`, `touch`, `totalPrice`, `isStale`}. `description` is excluded as a whole-value witness (default).
2. Accesses:
   - `add`: the bare `items` gets no `.fromScope` result (the parameter is `item`), then `.lookForMembers` for `Inventory`, which declares it. `add` touches `items`.
   - `touch` touches `lastUpdated` the same way.
   - `totalPrice`: lookup for `items` returns `.lookForGenericParameters` first. `Inventory` has no generic parameters, so the walk skips it and reaches `.lookForMembers` for the extension, which maps to the merged `Inventory`. `totalPrice` touches `items`. Inside the closure, `$0` and `$1` are implicit closure parameters (§7.2 step 1).
   - `isStale`: the shorthand `guard let lastUpdated` (rule 3) walks past `.lookForGenericParameters` to the member. The later `lastUpdated` gets a `.fromScope` result for the `guard` binding, so it is a local. `isStale` touches `lastUpdated`.
3. Edges: `add`–`totalPrice` (both touch `items`); `touch`–`isStale` (both touch `lastUpdated`); `add`–`touch` (call `self.touch()`).
4. One component, which touches attributes. **LCOM4 = 1.** `isolatedMembers` = []. `unusedAttributes` = [].

**What merging changes:**

- `Inventory.swift` alone gives M = {`add`, `touch`}, joined by the call, so LCOM4 = 1.
- `Inventory+Reporting.swift` alone gives an extension group, because `Inventory` is not declared in that file. Null, reason `notApplicableKind`.
- If `add` did not call `touch`, the merged type would have two components, {`add`, `totalPrice`} and {`touch`, `isStale`}, so LCOM4 = 2. `Inventory.swift` alone would also give 2, with {`add`} and {`touch`}. Merging adds members to the groups, and names the extension each came from; it does not change the count here. The count cannot exceed |A| = 2 either way.

**Ce:**

- `[Item]` (`ArrayTypeSyntax.element` → `Item`) gives a `storedProperty` edge.
- `add(_ item: Item)` gives a `signature` edge to the same target.
- `Date`, `String`, `Bool`, `Array`, `Optional` and `CustomStringConvertible` are `platform` from the Swift and Foundation interfaces. `Decimal` and `TimeInterval` are `platform` from the Foundation API notes (§7.4).
- **Ce = 1** (`ceConcrete` 1, `ceProtocol` 0, `ceView` 0, `ceNamespace` 0). `ceFamily` = 1. `platformNameCount` = 8, `externalNameCount` = 0. `caWithinModule(Item)` = 1. Ce(`Item`) = 0.

**Fan-out:**

- `add`: headline 2: `?.append(_:)`, `self.touch()`.
- `touch`: headline 1: `Date.init()`.
- `totalPrice`: headline 1: `?.reduce(_:_:)`, with the trailing closure adding `_`. The `+` is an operator token, and its operands contain no calls.
- `description`: headline 0: interpolation and property reads only.
- `isStale`: headline 1: `Date.init()`. `fanOutChained` 1: `chain.timeIntervalSince(_:)`, whose receiver is the call `Date()`. The `>` is an operator token; its operands are walked.

All other separate counts are 0.

### 12.2 A type that splits into two cohesion groups

```swift
final class SessionController {
    private var token: String?
    private var expiry: Date?
    private var recentSearches: [String] = []
    private let maxRecent = 10

    init() {}

    func signIn(token: String, validFor seconds: TimeInterval) {
        self.token = token
        expiry = Date().addingTimeInterval(seconds)
    }
    var isSignedIn: Bool {
        guard let expiry else { return false }
        return token != nil && expiry > Date()
    }
    func signOut() { token = nil; expiry = nil }

    func record(search: String) {
        recentSearches.insert(search, at: 0)
        trimRecent()
    }
    private func trimRecent() {
        if recentSearches.count > maxRecent {
            recentSearches.removeLast(recentSearches.count - maxRecent)
        }
    }
    func clearSearches() { recentSearches.removeAll() }
}
```

**Sizes.** NOA = 4 (`maxRecent` is a stored `let`). The class has no superclass, so |A| = 4. NOM = 7: `instanceMembers` 7 (including `init`), `staticMembers` 0, `initialisers` 1, `computedProperties` 1.

**LCOM4, step by step:**

1. M = {`signIn`, `isSignedIn`, `signOut`, `record`, `trimRecent`, `clearSearches`}. `init` is excluded.
2. Accesses:
   - `signIn`: in `self.token = token`, the right-hand `token` is the parameter (lookup returns `.fromScope` first), and `self.token` is the member. The bare `expiry` reaches `.lookForMembers`. So `signIn` touches `token` and `expiry`.
   - `isSignedIn`: `expiry` (shorthand binding) and `token`.
   - `signOut`: `token` and `expiry`.
   - `record`: `recentSearches`, plus a call to `trimRecent`.
   - `trimRecent`: `recentSearches` and `maxRecent`.
   - `clearSearches`: `recentSearches`.
3. The components are:
   - {`signIn`, `isSignedIn`, `signOut`}, touching {`token`, `expiry`};
   - {`record`, `trimRecent`, `clearSearches`}, touching {`recentSearches`, `maxRecent`}.
4. **LCOM4 = 2**, within the bound of |A| = 4. Each component has 3 members, so the possible `lowCohesionType` rule would fire.

**Sensitivity.** Suppose the class had `init(token: String?)`, setting `token` and clearing `recentSearches`. Counting initialisers would join the groups (LCOM4 = 1). Excluding them keeps 2. That is why `init` is excluded (§9.3).

**Ce = 0.** Every named type is `platform`: `String`, `Optional`, `Date`, `Array`, `Bool`, and `TimeInterval` through the API notes. `platformNameCount` = 6. A type can have low cohesion and no coupling.

**Fan-out:**

- `signIn`: headline 1: `Date.init()`. `fanOutChained` 1: `chain.addingTimeInterval(_:)`.
- `record`: headline 2: `?.insert(_:at:)`, `self.trimRecent()`.
- `trimRecent`: headline 1: `?.removeLast(_:)`.
- `clearSearches`: headline 1: `?.removeAll()`.
- `isSignedIn`: headline 1: `Date.init()`.
- `signOut`: headline 0.

### 12.3 A struct whose methods use no stored properties

```swift
struct PriceFormatter {
    let currencyCode: String
    let locale: Locale

    func format(_ amount: Decimal) -> String {
        amount.formatted(.currency(code: "EUR"))
    }
    func formatRange(_ low: Decimal, _ high: Decimal) -> String {
        "\(format(low)) – \(format(high))"
    }
    static func rounded(_ amount: Decimal) -> Decimal {
        var value = amount
        var result = Decimal()
        NSDecimalRound(&result, &value, 2, .bankers)
        return result
    }
}
```

**Sizes.** NOA = 2. NOM = 3: `instanceMembers` 2, `staticMembers` 1.

**LCOM4, step by step:**

1. M = {`format`, `formatRange`}. `rounded` is static and excluded.
2. Accesses: none. No `self` is used as a value, so rule 6 adds nothing. `format` ignores `currencyCode`, which is probably a bug.
3. Edges: `formatRange`–`format`, through the call `self.format(_:)`.
4. One component, and it is attribute-free. It is removed, and both members go to `isolatedMembers`.
5. No component remains. |A| = 2 and |M| = 2, so the first three null reasons do not apply. **LCOM4 = null, reason `noStateUse`.** `unusedAttributes` = [`currencyCode`, `locale`].

Reporting 1 would claim cohesion that does not exist. Reporting 0 would read as "perfect". Null with the unused attributes is the honest answer. The memberwise initialiser still uses the attributes, so `unusedAttributes` is a census value, not a defect by itself.

**Ce = 0.** `Locale`, `String` and `Decimal` are `platform` (`platformNameCount` = 3). `NSDecimalRound` is a type-name candidate, but §7.3 step 3 finds it in the platform free-function table (a `FOUNDATION_EXPORT` function, §7.4), so it is a function, not a type.

**Fan-out:**

- `format`: headline 1: `?.formatted(_:)`. `fanOutImplicitMember` 1: `..currency(code:)`.
- `formatRange`: headline 1: two calls with the same key, `self.format(_:)`.
- `rounded`: headline 2: `Decimal.init()`, `free.NSDecimalRound(_:_:_:_:)`. `.bankers` is an implicit member but not a call.

**Parameters.** `formatRange`: `parameterCount` = 2. `rounded`: `parameterCount` = 1, `inoutParameterCount` = 0. The `&` arguments are inout at the call site, not inout parameters.

### 12.4 A function using a singleton and globals

```swift
// App/Globals.swift
var requestCount = 0
let defaultTimeout: TimeInterval = 30

// App/APIClient.swift
final class APIClient {
    static let shared = APIClient()
    static var verbose = false
    func send(_ request: URLRequest) async throws -> Data { /* … */ }
}

// App/Endpoint.swift
enum Endpoint {
    case profile, settings
    var url: URL { /* … */ }
}

// App/ProfileLoader.swift
struct Profile: Decodable { let name: String }

struct ProfileLoader {
    func load(userID: String) async throws -> Profile {
        requestCount += 1
        var request = URLRequest(url: Endpoint.profile.url)
        request.timeoutInterval = defaultTimeout
        if APIClient.verbose { print("GET \(request)") }
        let data = try await APIClient.shared.send(request)
        return try JSONDecoder().decode(Profile.self, from: data)
    }
}
```

**Common coupling for `load(userID:)`, step by step:**

1. **`requestCount`:**
   - Lookup gives no `.fromScope` name.
   - It reaches `.lookForMembers` for `ProfileLoader`, which does not declare `requestCount`, so the walk skips it. No results remain.
   - The module table has a top-level `var requestCount`, so it is a global, and mutable.
2. **`defaultTimeout`:** the same steps make it a global. It is a `let`, so it is not mutable.
3. **`request`:** lookup returns `.fromScope` (the local `var`). Not coupling.
4. **`Endpoint.profile`:** `Endpoint` is a type-name candidate that resolves to a module enum. `profile` matches an `EnumCaseElementSyntax.name`, so it is excluded from `staticRefs`. `.url` is an instance property.
5. **`APIClient.verbose`:** a static stored `var` of a module type. It counts in `staticRefs` and `mutableStaticRefs`.
6. **`APIClient.shared`:** a stored `static let` in a class, initialised by `APIClient()`, the enclosing type. It is a singleton and counts in `staticRefs` and `singletonRefs`.
7. **`Profile.self`:** a metatype. Excluded.

Result: `globalRefs` = 2, `mutableGlobalRefs` = 1, `staticRefs` = 2, `mutableStaticRefs` = 1, `singletonRefs` = 1.

**Fan-out:** headline 3: `URLRequest.init(url:)`, `?.send(_:)` and `JSONDecoder.init()`. `fanOutChained` 1: `chain.decode(_:from:)`, whose receiver is the call `JSONDecoder()`.

- `print(_:)` is on the diagnostic exclusion list.
- `+=` is an operator token.
- `try` and `await` are walked through.

`APIClient.shared.send` gets receiver `?`, because its base is a member access, not a call, and v1 does not type a member chain.

**Ce(ProfileLoader) = 3**, all `ceConcrete` (`Endpoint` has cases, so it is not a namespace):

- `Profile`: `signature` (return type) and `body` (`Profile.self`);
- `Endpoint`: `body`;
- `APIClient`: `body`.

`ceFamily` = 3. `String`, `URLRequest` and `JSONDecoder` are `platform` (`platformNameCount` = 3; `JSONDecoder` is harvested as an `open class`). `TimeInterval` is named in `Globals.swift`, not in `ProfileLoader`. This adds 1 to `caWithinModule` for each of `Profile`, `Endpoint` and `APIClient`.

**ProfileLoader cohesion:** |A| = 0 and |M| = 1. Both `noStoredProperties` and `fewerThanTwoMembers` hold; by the precedence in §9.3 the reason is `noStoredProperties`.

### 12.5 A protocol with a default implementation

```swift
protocol Shape {
    var area: Double { get }
    var name: String { get }
}
extension Shape {
    var summary: String { "\(name): \(area)" }
    func isLarger(than other: some Shape) -> Bool { area > other.area }
}

struct Circle: Shape {
    var radius: Double
    var area: Double { .pi * radius * radius }
    var name: String { "circle" }
    func scaled(by factor: Double) -> Circle { Circle(radius: radius * factor) }
    func describe() -> String { summary }
}
```

**Shape (protocol type):**

- `nom` = 2 (`area`, `name`). `requirementCount` = 2.
- `defaultImplementationCount` = 2, with `defaultsForRequirements` = 0 and `extensionOnlyMembers` = 2.
- `wmcDefaults` = cc(`summary.get`) + cc(`isLarger`) = 0. Neither body has an increment or a decision: interpolation and `>` cost nothing.
- Cohesion: null (`notApplicableKind`).
- Ce = 0. `some Shape` in its own extension is a self-reference, and `Double`/`String` are `platform`.
- `conformerCount` = 1. `caWithinModule` = 1.

**Circle:** NOA = 1 (`radius`), so |A| = 1. NOM = 4 (`area`, `name`, `scaled`, `describe`): `instanceMembers` 4, `computedProperties` 2. The protocol's defaults are not Circle's members, so they add nothing to Circle's NOM or WMC.

**LCOM4, step by step:**

1. M = {`area`, `name`, `scaled`, `describe`}.
2. Accesses:
   - `area` touches `radius`. `.pi` is an implicit member, not an attribute.
   - `scaled` touches `radius`. `Circle(radius:)` is an initialiser call, and initialisers are not in M, so it adds no edge.
   - `name` touches nothing.
   - `describe`: the bare `summary` reaches `.lookForMembers` for `Circle`, but Circle does not declare it and has no superclass. The walk ends, and the module has no global or free function named `summary`. `unresolvedMemberRefs` = [`summary`], and no edge.
3. Components: {`area`, `scaled`} touches `radius`. {`name`} and {`describe`} are attribute-free, so they go to `isolatedMembers`.
4. **LCOM4 = 1.** With |A| = 1 it could only be 1 or null. Without the attribute-free rule it would be 3, which would wrongly suggest splitting a small, coherent type.

**Ce(Circle) = 1**, a `conformance` edge to the protocol `Shape` (`ceProtocol` = 1). The self-reference in `scaled`'s signature and body is excluded. `ceFamily` = 1.

**Fan-out:** `scaled`: headline 1 (`Circle.init(radius:)`). `describe`, `area` and `name`: headline 0. Reading `summary` is a property read. If it were a method call, `summary()`, the key would be `implicit.summary()`: an unqualified callee that §7.2 does not resolve.

### 12.6 Module coupling

Package targets and their imports:

- `Core` imports Foundation.
- `Networking` imports Foundation and Core.
- `App` imports SwiftUI, Core and Networking.
- `CoreTests` imports Core and XCTest. It is a test module.

| Module | ceAll | cePackage | ceWithReexports | ca | caWithReexports | caTests | instability |
|---|---|---|---|---|---|---|---|
| Core | 1 (Foundation) | 0 | 0 | 2 (Networking, App) | 2 | 1 | 0 / (2 + 0) = **0** |
| Networking | 2 | 1 (Core) | 1 | 1 (App) | 1 | 0 | 1 / (1 + 1) = **0.5** |
| App | 3 | 2 | 2 | 0 | 0 | 0 | 2 / (0 + 2) = **1** |
| CoreTests | 2 (Core, XCTest) | 1 (Core) | 1 | 0 | 0 | 0 | 1 / (0 + 1) = **1** |

If `Networking` contained `@_exported import Core`, then `App`'s `ceWithReexports` would still be 2, because Core is already a direct import. A new module `Feature` importing only `Networking` would get `cePackage` = 1 and `ceWithReexports` = 2. Assuming `Feature` is not a test module, Core's `ca` would stay 2 (Networking, App) and its `caWithReexports` would become 3 (Networking, App, Feature). Networking's `ca` would become 2 (App, Feature).

### 12.7 Corpus checks

Hand counts made on 2026-11-17 against the files cited, under the rules in Part B. They are not prototype output. "Draft rules" means the previous draft of Part B: first-result lookup, no pattern, implicit-member or chained split, `nonisolated` excluded, no superclass attributes, and a singleton test that accepted a type annotation.

| Type | Draft rules | Part B | Rule that changed it |
|---|---|---|---|
| TCA reducer `SyncUpDetail` (swift-composable-architecture/Examples/SyncUps/SyncUps/SyncUpDetail.swift:4–117) | `body` fan-out 19. Ce 1. Destination Ce 0. | NOA 3, NOM 1, LCOM4 null (`fewerThanTwoMembers`), `hasKnownAttachedMacro` true. `body`: 6 pattern-position call sites excluded; headline 8, `fanOutImplicitMember` 6 (`.alert`, `.edit`, `.run`, `.send`, `.delegate`, `.startMeeting`), `fanOutChained` 1 (`.ifLet`). Ce 1 (`SyncUpForm.State`). Destination Ce 1 (`SyncUpForm`, `casePayload`). `ceFamily` 2 (`SyncUpForm`, `SyncUp`). The `Destination.State` extension at :118 is an unresolved extension. | Pattern exclusion; `.` and `chain` split; `casePayload`; `ceFamily`; unresolved extensions |
| SwiftUI view `ContentView` (SwiftProjectLint/Sources/App/ContentView.swift:48–184) | LCOM4 1, but `body` isolated. Ce 11. `decoratedMainStack` fan-out 15. | NOA 2, NOM 9, \|M\| 8, LCOM4 1, nothing isolated by lookup. Ce 11 = `ceView` 7 + `ceConcrete` 4 (`SystemComponents`, `ContentViewModel`, `RuleSelectionWindowController`, `RuleSelectionConfig`). `decoratedMainStack`: headline 8, `fanOutChained` 7. `singletonRefs` 1 (`RuleSelectionWindowController.shared`). | Lookup walk; `ceView`; `chain` split |
| swift-nio `ServerSocketChannel` (swift-nio/Sources/NIOPosix/SocketChannel.swift:206) | NOA 2, \|M\| 20, LCOM4 2, 14 isolated. | \|A\| is every stored instance property of `BaseSocketChannel` (about 20, declared from BaseSocketChannel.swift:282) plus the subclass's own `backlog` and `group`. The subclass's members touch three of the inherited ones: `socket`, `readPending` and `maxMessagesPerRead` (BaseSocketChannel.swift:290, 299, 302). LCOM4 1, 10 isolated. The two `bind0(to:promise:)` are joined by label. | Superclass attributes |
| SwiftStats `FunctionCollector` (SwiftStats/Sources/SwiftStatsCore/Functions/FunctionCollector.swift:13, with +Records.swift and +Syntax.swift) | Draft text claimed LCOM4 3; the draft rules give 2. Ce 14. | NOA 8, NOM 55, \|M\| 46. LCOM4 1; isolated: `visit(MacroExpansionExprSyntax)`, `visit(MacroExpansionDeclSyntax)`. Ce 14 = `ceConcrete` 11 + `ceNamespace` 3 (`CanonicalText`, `DeclarationRenderer`, `BodyHash`). `externalNameCount` about 28. | Lookup walk; `ceNamespace` |
| swift-collections `Heap` (HeapModule/Heap.swift:63 and five extension files) | `singletonRefs(popMin)` 1. | NOA 1, NOM 27 (`instanceMembers` 25 including 4 initialisers, `staticMembers` 2; the `#if` variants of `_checkInvariants()` merged). LCOM4 1 (the \|A\| = 1 bound). Ce 1 (`_HeapNode`; `_UnsafeHandle` is in the family). `singletonRefs(popMin)` 0: `_HeapNode` is a type-name candidate (leading underscores are skipped, §7.3), and `_HeapNode.root` is computed, so it counts in `staticRefs` only. | Stricter singleton rule |
| swift-nio `MarkedCircularBuffer` (swift-nio/Sources/NIOCore/MarkedCircularBuffer.swift) | as on the right, except Ce and `ceFamily` (not rechecked under the draft rules) | NOA 2, NOM 21, \|M\| 19, LCOM4 1. Ce 2: `CircularBuffer` and its nested struct `CircularBuffer.Index` (swift-nio/Sources/NIOCore/CircularBuffer.swift:77), both `ceConcrete`, because `A.B` targets the nested type (§7.3 step 4; the `Index` typealias resolves to it). `ceFamily` 1 (`CircularBuffer`). `unresolvedMemberRefs` [`formIndex`]. Value types with a shared backing store come out cohesive without the whole-`self` rule. | None |
| GRDB `DispatchQueueActor` (GRDB/Core/DispatchQueueActor.swift:10–25) | Null (`fewerThanTwoMembers`): `unownedExecutor` excluded as `nonisolated`. | M = {`unownedExecutor`, `execute`}. LCOM4 1; `execute` isolated. | `nonisolated` kept in M |

---

## 13. Library API

The package has one library product, `SwiftCodeMetrics`. It depends on `SwiftSyntax` and, from v0.2, `SwiftLexicalLookup`, both from swift-syntax `exact: "603.0.2"`. From v0.2 that also links `SwiftIfConfig`, `SwiftParser`, `SwiftOperators`, `SwiftSyntaxBuilder` and `SwiftDiagnostics` indirectly, though the library calls none of them (§1.3). Tests use `SwiftParser`, `SwiftOperators` (for folded-tree tests) and Swift Testing. The platform-table generator (§7.4) is a separate executable target that uses `SwiftParser`; the library product does not link it.

### 13.1 Entry points

There is one entry point per level. The function level needs one declaration. The type level needs every file of a module, because extensions and globals are spread across files. The module level needs every module of the scan, because Ca counts importers.

| Level | Entry point | Needs | Gives |
|---|---|---|---|
| Function | `functionMetrics(of:)` | one declaration, or one file | function records with final complexity; coupling `nil` |
| Type | `analyzeModule(_:)` | every file of one module | function records with complexity and coupling; type records; the type graph and its cycles; import facts |
| Module | `analyzePackage(_:)` | the `ModuleAnalysis` of every module in the scan | module Ce, Ca and instability; module edges |

The type level runs in two passes (§7.1). Its file pass is also exposed as `analyzeFile`, and a second form of `analyzeModule` takes file passes the caller already has, so a caller can cache the file pass.

```swift
import SwiftSyntax

public enum SwiftCodeMetrics {
    /// Library and definition versions (§13.4). Every result carries a copy.
    public static let version: MetricsVersion

    // MARK: Function level: one declaration, no module context

    /// Scores every function in `declaration`: the declaration's own function(s) first,
    /// then nested functions, local computed and observed variables, local-type members
    /// and local-type property initialisers, in record order (below).
    /// A `func` gives one record; a property or subscript with `get`/`set` gives one per accessor;
    /// a type or extension gives a record per member, recursively, and a `.propertyInitializer`
    /// record for each stored property whose initial value has non-zero C or D (§2.1, Q6).
    /// Complexity is final. Coupling fields are nil, with `couplingStatus == .needsModulePass`.
    public static func functionMetrics(
        of declaration: some DeclSyntaxProtocol,
        module: String = "",
        file: String? = nil,                     // used in the keys of private and fileprivate declarations
        options: MetricsOptions = .init(),
        locations: SourceLocationConverter? = nil
    ) -> FunctionAnalysis

    /// The same for a whole file, adding a `.topLevelCode` record when the file has top-level
    /// statements, and `.propertyInitializer` records for global variables (§2.1, Q6).
    /// Line and column ranges are always filled, from the file's own converter.
    public static func functionMetrics(
        of file: SourceFileInput,
        module: String = "",
        options: MetricsOptions = .init()
    ) -> FunctionAnalysis

    // MARK: Type level: every file of one module

    /// Runs the file pass on every file, then the module pass (§7.1).
    /// Finalises function coupling and parameter counts, and computes every type metric.
    public static func analyzeModule(
        _ module: ModuleInput,
        options: MetricsOptions = .init(),
        platformTable: PlatformTable = .bundled
    ) -> ModuleAnalysis

    /// Pass 1 alone. Per file, safe to run in parallel, cacheable (§13.6).
    /// Complexity scores are final here. Everything else is raw until the module pass.
    public static func analyzeFile(
        _ file: SourceFileInput,
        module: String,
        options: MetricsOptions = .init()
    ) -> FileAnalysis

    /// Pass 2 over file passes the caller already has. Needs the FileAnalysis of every file
    /// in the module, made with the same options and library version.
    public static func analyzeModule(
        name: String,
        isTest: Bool,
        files: [FileAnalysis],
        options: MetricsOptions = .init(),
        platformTable: PlatformTable = .bundled
    ) -> ModuleAnalysis

    // MARK: Module level: every module of the scan

    /// Pass 3. Needs every ModuleAnalysis in the scan.
    public static func analyzePackage(_ modules: [ModuleAnalysis]) -> PackageAnalysis
}
```

**Record order.** Every array of function records (`FunctionAnalysis.functions`, `FileAnalysis.functions`, `ModuleAnalysis.functions`) uses one order. The records of a file form a tree by `parentID`, and are listed pre-order depth-first: a record comes before its children, and siblings, the roots included, are ordered by the start UTF-8 offset of their `range`. A `.topLevelCode` record's `range` runs from the start of the file's first top-level statement to the end of its last, and its children are the records declared inside those statements. `ModuleAnalysis.functions` lists the files in the order of `ModuleInput.files` (or of the `files` argument). `FunctionRecord.id` is the index in the returned array, so golden fixtures depend on this order.

**Inputs and options.**

```swift
public struct SourceFileInput: Sendable {
    public var path: String
    public var tree: SourceFileSyntax        // callers parse; the library never reads files
    public init(path: String, tree: SourceFileSyntax)
}

public struct ModuleInput: Sendable {
    public var name: String
    public var files: [SourceFileInput]      // explicit list; the library never walks directories
    public var isTest: Bool
    public init(name: String, files: [SourceFileInput], isTest: Bool)
}

public struct MetricsOptions: Sendable, Hashable, Codable {
    public var complexity = ComplexityOptions()
    public var cohesion = CohesionOptions()
    /// Free functions left out of fan-out when the module does not declare them (§8.1).
    public var diagnosticFreeFunctions: Set<String> = [
        "assert", "assertionFailure", "precondition", "preconditionFailure",
        "fatalError", "print", "debugPrint", "dump",
    ]
    public init() {}
}

public struct ComplexityOptions: Sendable, Hashable, Codable {
    /// SwiftLint `ignores_case_statements`; affects only `swiftLintCompatible`.
    public var swiftLintIgnoresCaseStatements = false
    public var detectRecursion = true
    /// Lint only (§4.2). SwiftStats leaves it off and stores raw D.
    public var decisionCountIgnoresTrivialSwitches = false
    /// Protocols whose `some P` result sets `.opaqueResult` (§5). Matched by last name component.
    public var opaqueResultBuilderProtocols: Set<String> = [
        "View", "Scene", "Commands", "ToolbarContent", "CustomizableToolbarContent",
        "Widget", "WidgetConfiguration", "ChartContent", "MapContent",
        "TableColumnContent", "TableRowContent",
    ]
    public init() {}
}

public struct CohesionOptions: Sendable, Hashable, Codable {
    public var excludeDescriptionWitnesses = true                  // §9.3, Q21
    public var wholeSelfInStructs = true                           // §9.3 rule 6, Q20
    public var dropAttributeFreeComponents = true                  // §9.3, Q22
    public var inheritsModuleSuperclassAttributes = true           // §9.3, Q32
    public init() {}
}
```

The platform table is a parameter of the module pass, not an option. That keeps `MetricsOptions` small enough to store with every snapshot. The table's own version is in `MetricsVersion` (§13.4).

### 13.2 Function records

```swift
public struct FunctionAnalysis: Sendable, Codable {
    public var version: MetricsVersion
    public var options: MetricsOptions
    public var functions: [FunctionRecord]
}

public struct FunctionRecord: Sendable, Codable, Hashable, Identifiable {
    public let id: Int                          // index in the returned array, in record order (§13.1)
    public let parentID: Int?                   // enclosing function, for nested and local ones
    public let key: MemberKey                   // PRD §6.1 syntactic key (§2.1, Q1)
    public let parentKey: MemberKey?
    public let kind: FunctionKind
    public let name: String                     // "loadConfig(from:attempt:)", "subscript(_:).get", "body.get"
    public let range: ByteRange
    public let lines: LineRange?                // filled when locations are known
    public let complexity: ComplexityScores     // final at every level

    public let couplingStatus: CouplingStatus
    public let parameters: ParameterCounts?     // nil until the module pass, and for kinds without parameters (§8.3)
    public let fanOut: FanOut?                  // nil until the module pass (self vs implicit needs merged types)
    public let commonCoupling: CommonCoupling?  // nil until the module pass (needs the module table)
    public let typeReferences: [TypeReference]  // raw after the file pass; resolved after the module pass
}

public enum CouplingStatus: String, Sendable, Codable {
    case computed
    case needsModulePass                        // function level, or a file pass not yet merged
    case notApplicableKind                      // `.propertyInitializer` (§2.1)
}

/// The PRD §6.1 syntactic key, rendered by the library (Q1).
public struct MemberKey: Hashable, Sendable, Codable {
    public var module: String
    public var text: String                     // the other key parts in canonical form, `#if` condition included
    public var file: String?                    // only for private and fileprivate declarations
    public init(module: String, text: String, file: String? = nil)
}

/// Start and end line and column, 1-based, as PRD §6.1 asks every record to store.
public struct LineRange: Sendable, Codable, Hashable {
    public let startLine: Int
    public let startColumn: Int
    public let endLine: Int
    public let endColumn: Int
}

public enum FunctionKind: String, Sendable, Codable {
    case function, initializer, deinitializer
    case subscriptGetter            // implicit getter of a subscript
    case computedGetter             // implicit getter of a computed property or local variable
    case accessor                   // explicit get/set/willSet/didSet/_modify/…
    case propertyInitializer        // stored-property initial value (Q6)
    case topLevelCode               // file walker only (Q6)
}

public enum ResultBuilderHint: Sendable, Codable, Hashable {   // no hint is nil, not a `.none` case
    case attribute(String)          // last name component: "ViewBuilder" for @SwiftUI.ViewBuilder
    case opaqueResult(String)       // last name component of P in `some P`: "View", "Scene"
}

/// UTF-8 byte offsets from the start of the file, as in `AbsolutePosition.utf8Offset`.
public struct ByteRange: Sendable, Codable, Hashable {
    public let start: Int           // inclusive
    public let end: Int             // exclusive
}

extension FunctionKind {
    /// SwiftStats' `FunctionKind` raw value (§2.1); nil for `.propertyInitializer`.
    public var swiftStatsKind: String? { get }
}

public struct ComplexityScores: Sendable, Codable, Hashable {
    public let cognitive: Int
    public let decisionCount: Int
    public var mccabe: Int { decisionCount + 1 }    // derived, not encoded
    public let swiftLintCompatible: Int
    public let swiftLintScoresKind: Bool    // true only for `func` and `init`

    /// The highest level any construct gives its contents, closures and `defer` included.
    /// 0 for a body with no nesting construct; 1 for `if c {}`.
    public let maxNesting: Int
    public let resultBuilderHint: ResultBuilderHint?    // nil when the body isn't a builder body
    public let hasSyntaxErrors: Bool

    /// Every increment that contributed to any of the three scores.
    public let items: [Increment]
}

public struct Increment: Sendable, Codable, Hashable {
    public enum Metric: String, Sendable, Codable { case cognitive, decision, swiftLint }

    public enum Rule: String, Sendable, Codable {
        // shared: used by every metric that counts the construct
        case ifStatement, elseIf, guardStatement, loop, catchClause, ternary
        // cognitive only
        case elseClause, switchStatement, conditionalCompilation, conditionalCompilationElse
        case conditionList, logicalSequence, labeledJump, fallthroughJump
        case recursion, possibleRecursion   // possibleRecursion always has amount 0
        // decision count only
        case conditionElement, switchArms, trivialSwitch, whereClause, forCasePattern
        case logicalOperator, nilCoalescing
        // SwiftLint-compatible only
        case switchCase, fallthroughStatement
    }

    public let metric: Metric
    public let rule: Rule
    public let amount: Int          // total for this item; −1 for fallthroughStatement; 0 only for possibleRecursion
    public let nesting: Int         // the nesting part of `amount` (cognitive structural only, else 0)
    public let closureNesting: Int  // the part of `nesting` from enclosing closures (ClosureExprSyntax only, not `defer`)
    public let utf8Offset: Int      // anchor token, see notes
    public let line: Int?           // filled when `locations` is given, and always for the file form
    public let column: Int?
}

public struct ParameterCounts: Sendable, Codable, Hashable {
    public var parameterCount: Int
    public var defaultedParameterCount: Int
    public var variadicParameterCount: Int
    public var inoutParameterCount: Int
    public var closureParameterCount: Int
    public var escapingClosureParameterCount: Int
}

public struct FanOut: Sendable, Codable, Hashable {
    public var fanOut: Int                           // distinct keys, excluding "." and chain
    public var fanOutImplicitMember: Int
    public var fanOutChained: Int
    public var byReceiver: [ReceiverKind: Int]       // self, super, T, free, implicit, ".", chain, "?"
    public var distinctBaseNames: Int
    public var macroExpansionCount: Int
    public var calls: [CallKeyItem]                  // the breakdown: one item per distinct key
}

public enum ReceiverKind: String, Sendable, Codable, CodingKeyRepresentable {
    case `self`, `super`, type = "T", free, implicit, implicitMember = ".", chain, unknown = "?"
}

public struct CallKeyItem: Sendable, Codable, Hashable {
    public var key: String                           // "self.touch()", "?.append(_:)", "Date.init()" (§7.5)
    public var receiver: ReceiverKind
    public var siteCount: Int                        // call sites with this key
    public var firstUTF8Offset: Int                  // anchor: the callee of the first site
}

public struct CommonCoupling: Sendable, Codable, Hashable {
    public var globals: [String]                     // globalRefs = globals.count (§8.2)
    public var mutableGlobals: [String]
    public var statics: [String]                     // "APIClient.verbose"
    public var mutableStatics: [String]
    public var singletons: [String]                  // "APIClient.shared"
    public var globalRefs: Int { globals.count }     // derived, not encoded; likewise for the others
}

public struct TypeReference: Sendable, Codable, Hashable {
    public var spelling: String                      // as written, generic arguments stripped
    public var edgeKind: EdgeKind                    // signature or body, for a function
    public var utf8Offset: Int
    public var bucket: TypeBucket?                   // module, platform, external; nil until the module pass
    public var target: TypeKey?                      // set for the module bucket (§7.3)
    public var resolution: Resolution
    public var resolvedName: String?                 // platform or external: the type named, qualifiers stripped, aliases expanded
}
public enum TypeBucket: String, Sendable, Codable { case module, platform, external }
```

### 13.3 Breakdowns

- **Anchors.** Every item's `utf8Offset` is the start of one token, fixed by its rule:
  - `ifStatement`: the `if` keyword. `elseIf`: the `if` keyword that follows `else`. `elseClause`: the `else` keyword. `guardStatement`: `guard`.
  - `loop`: `for`, `while`, or the `repeat` keyword of a `repeat` loop. `catchClause`: `catch`.
  - `switchStatement`, `switchArms` and `trivialSwitch`: the `switch` keyword. `switchCase`: the `case` keyword, or the `default` keyword for `default` and `@unknown default`.
  - `conditionalCompilation`: `#if`. `conditionalCompilationElse`: the `#elseif` or `#else` token.
  - `conditionList` and `conditionElement`: the first comma of the condition list. D emits one `conditionElement` item per list, whose amount is the number of elements minus 1.
  - `labeledJump`: the `break` or `continue` keyword. `fallthroughJump` and `fallthroughStatement`: `fallthrough`.
  - `whereClause`: `where`. `forCasePattern`: the `case` keyword.
  - `logicalSequence`: the first operator of the run. `logicalOperator` and `nilCoalescing`: the operator. `ternary`: the `?`.
  - `recursion`: the callee of the first matching call. `possibleRecursion`: the callee of each such call.
- **Rule choice and zero amounts.** An SL `else if` item uses `elseIf`, as the cognitive and decision items do. Only `possibleRecursion` items have amount 0. No other zero-amount item is emitted: a switch with zero or one counted arm has no `switchArms` item.
- **Shared rule cases.** `ifStatement`, `elseIf`, `guardStatement`, `loop` (`for`, `while`, `repeat`), `catchClause` and `ternary` are used by every metric that counts the construct. A cognitive `if` and a decision `if` are two items with the same rule and different metrics.
- `functionMetrics(of:)` accepts unfolded trees, which is the normal case, and folded trees (§3.5.1).
- The returned values are plain data, so SwiftStats can store them and SwiftProjectLint can format them. Explaining a score is a filter on `items`, for example `items.filter { $0.metric == .cognitive }`. The sum of `amount` over a metric's items equals that metric's score. For `.decision`, a `#if` contributes only the items of its chosen clause (§4.2), so the sum still matches.
- **Coupling breakdowns.** `FanOut.calls` lists every distinct call key, so `fanOut` and its splits are counts over that list. `CommonCoupling` lists the names behind each count. A type's `typeEdges` (below) list every Ce target with its edge kinds. `CohesionResult.components` lists each group's members, the attributes it touches and the extensions it comes from. Unresolved and ambiguous names are listed, not only counted.

### 13.4 Versions and provenance

```swift
public struct MetricsVersion: Sendable, Codable, Hashable {
    public let library: String              // the package release, e.g. "0.1.0"
    public let swiftSyntax: String          // "603.0.2"
    public let complexityDefinition: String // "complexity-1" (Q4)
    public let couplingDefinition: String?  // "coupling-1" (Q4); nil before v0.2
    public let platformTable: String?       // SDK version the platform table came from, e.g. "27.2"; nil when not used
    public let swiftLintReference: String   // "0.65.1": the SwiftLint release SL was checked against (§4.3)
}
```

- A definition version is bumped for any change that alters a value, including a change to a default option (Q4). The library version alone is not enough: a release can change no values, or change several definitions at once.
- `platformTable` is reported because a new SDK can move a name between the `platform` and `external` buckets without any rule changing (§7.4).
- `swiftLintReference` says which SwiftLint release the SL rules were checked against. SwiftLint's counting has changed between releases (§4.3), so a consumer that compares with SwiftLint also records the version it ran ([PRD]:147).
- Edge records carry their own `provenance` (`syntax` or `index`) and `resolution`, below, so the index collector can write the same shapes.

### 13.5 Type and module results

All are `Sendable` and `Codable`. Optionals mean "not defined", with a reason, never 0 (PRD §6.5).

```swift
public struct FileAnalysis: Sendable, Codable {
    public var path: String
    public var functions: [FunctionRecord]           // complexity final; coupling nil
    public var rawReferences: RawReferences          // call sites, names, lookup results (as StoredLookupResult)
    public var declarations: DeclarationFacts        // types, extensions, members, cases, globals, typealiases
    public var imports: [ImportFact]
    public var version: MetricsVersion
    public var options: MetricsOptions
}

public struct ModuleAnalysis: Sendable, Codable {
    public var module: String
    public var isTest: Bool
    public var functions: [FunctionRecord]           // all fields resolved
    public var types: [TypeResult]
    public var typeEdges: [TypeCoupling]
    public var typeCycles: [[TypeKey]]               // SCCs of size >= 2, syntactic
    public var unresolvedExtensions: [ExtensionFact] // e.g. extensions of macro-generated nested types
    public var imports: [ImportFact]
    public var version: MetricsVersion               // couplingDefinition and platformTable set
    public var options: MetricsOptions
}

public struct TypeResult: Sendable, Codable {
    public var key: TypeKey
    public var kind: TypeKind                        // struct, class, enum, actor, protocol, extensionGroup
    public var sizes: TypeSizes                      // nom (partition and subsets), noa, storedProperties, caseCount
    public var wmc: WMC                              // cognitive, decisions (or wmcDefaults for protocols)
    public var cohesion: CohesionResult
    public var coupling: TypeCouplingSummary         // ceTotal, ceConcrete, ceProtocol, ceView, ceNamespace,
                                                     // ceFamily, internalRefs, externalNameCount,
                                                     // platformNameCount, caWithinModule,
                                                     // unresolved and ambiguous counts
    public var declarationTypeReferences: [TypeReference]  // type names outside function bodies (below)
    public var unresolvedTypeRefs: [String]          // names, from declarations and member bodies (§7.3)
    public var ambiguousTypeRefs: [String]
    public var protocolFacts: ProtocolFacts?         // requirementCount, defaults, conformerCount
    public var extensions: [ExtensionFact]           // every merged extension (§9.1)
    public var conformances: [ConformanceFact]       // declaration and all extensions (§9.1, §9.5)
    public var superclass: TypeKey?
    public var possibleSuperclass: String?
    public var customAttributes: [String]
    public var hasKnownAttachedMacro: Bool
}

public struct CohesionResult: Sendable, Codable {
    public var lcom4: Int?
    public var nullReason: CohesionNullReason?       // first that holds: notApplicableKind,
                                                     // noStoredProperties, fewerThanTwoMembers, noStateUse
    public var components: [CohesionComponent]       // members, attributes touched, declaring extensions
    public var isolatedMembers: [MemberKey]
    public var excludedMembers: [ExcludedMember]     // key + reason
    public var unusedAttributes: [String]            // own attributes only
    public var unresolvedMemberRefs: [String]
    public var inheritedMemberRefs: [String]
    public var rootlessKeyPathNames: [String]
    public var nodeCount: Int                        // |M|
    public var noa: Int
    public var attributeCount: Int                   // |A|, with in-module superclass attributes
}

public struct ExtensionFact: Sendable, Codable, Hashable {
    public var file: String
    public var range: ByteRange
    public var extendedType: String                  // as written: "SyncUpDetail.Destination.State"
    public var conformances: [ConformanceFact]
    public var whereClause: String?                  // canonical text of the generic `where` clause
}

public struct ConformanceFact: Sendable, Codable, Hashable {
    public var name: String                          // as written, after the unwrapping in §9.1
    public var target: TypeKey?                      // set when it resolves to a module protocol
    public var isConditional: Bool
}

public struct PackageAnalysis: Sendable, Codable {
    public var modules: [ModuleCoupling]             // ceAll, cePackage, ceWithReexports, caDirect,
                                                     // caWithReexports, caTests, instability
    public var moduleEdges: [ModuleDependency]
    public var version: MetricsVersion
}
```

`declarationTypeReferences` holds the type's references that no `FunctionRecord` carries: stored-property annotations and initial values, inheritance clauses, generic and `where` clauses of the type and its extensions, `associatedtype` constraints, case payloads, member typealiases and wrapper attributes. A `.propertyInitializer` record's own `typeReferences` is empty, so each reference is listed once. `unresolvedTypeRefs` and `ambiguousTypeRefs` list the names behind the counts in `TypeCouplingSummary`.

**Stored lookup results.** `LookupResult` holds `Syntax` nodes (`SLL/LookupResult.swift:18–47`), so it cannot be encoded. The file pass stores each lookup result, in walk order, as a syntax-free `StoredLookupResult` inside `RawReferences`. That is all the §7.2 walk needs, so the module pass gives the same answers over decoded file passes as over live trees (the v0.2 caching test, §16).

```swift
public enum StoredLookupResult: Sendable, Codable, Hashable {
    case local                                  // .fromScope with a non-empty name list
    case members(typePath: [String])            // .lookForMembers(in:): the type's nominal path,
                                                // or an extension's extended type as written
    case genericParameters(typePath: [String])  // .lookForGenericParameters(of:): likewise
    case implicitClosureParameters              // .lookForImplicitClosureParameters
}
```

**Shared record shapes.** The library defines these so that SwiftStats' indexstore-db collector (M7) emits the same records with `provenance: .index`:

```swift
public struct TypeKey: Hashable, Sendable, Codable {
    public var module: String; public var path: [String]
    public var file: String?                         // only if private or fileprivate
    public var localTo: MemberKey?                   // only for a type declared in a function body
    public init(module: String, path: [String], file: String? = nil, localTo: MemberKey? = nil)
}
public enum Provenance: String, Sendable, Codable { case syntax, index }
public enum Resolution: String, Sendable, Codable { case exact, approximate, unresolved, ambiguous }

public enum EdgeKind: String, Sendable, Codable {
    case inheritance, conformance, refinement, storedProperty, casePayload,
         `typealias`, signature, constraint, wrapper, body
}

public struct TypeCoupling: Sendable, Codable {
    public var source: TypeKey; public var target: TypeKey
    public var kinds: Set<EdgeKind>
    public var isWeakOrUnowned: Bool                 // only if every storedProperty contribution is weak or unowned (§9.4)
    public var targetClass: TargetClass?             // protocol, view, namespace, concrete
    public var provenance: Provenance; public var resolution: Resolution
    public var usr: String?                          // filled by the index collector only
    public init(source: TypeKey, target: TypeKey, kinds: Set<EdgeKind>, isWeakOrUnowned: Bool,
                targetClass: TargetClass?, provenance: Provenance, resolution: Resolution,
                usr: String? = nil)
}
public struct ModuleDependency: Sendable, Codable {
    public var source: String; public var target: String
    public var viaExported: Bool; public var condition: String?
    public var provenance: ModuleDependencyProvenance   // import, index (§10.1)
    public init(source: String, target: String, viaExported: Bool, condition: String?,
                provenance: ModuleDependencyProvenance)
}
```

The types named but not spelled out here (`RawReferences`, `DeclarationFacts`, `ImportFact`, `TypeKind`, `TypeSizes`, `WMC`, `TypeCouplingSummary`, `ProtocolFacts`, `CohesionComponent`, `ExcludedMember`, `CohesionNullReason`, `ModuleCoupling`, `TargetClass`, `ModuleDependencyProvenance`, `PlatformTable`) hold the fields their sections define, and follow the same rules: `Sendable`, `Codable`, and optionals only for "not defined".

**General rules.**

- **Codable.** Every result type synthesises `Codable`. Positions are stored as UTF-8 offsets (`ByteRange`, `utf8Offset`). `AbsolutePosition` is only `Comparable, Hashable, Sendable` (`Sources/SwiftSyntax/AbsolutePosition.swift:15`), so a `Range<AbsolutePosition>` would block synthesis. Function records, increments and type references all use this one position format.
- Public types are `Sendable`, and the library has no global mutable state, as Swift 6 language mode requires.
- **Initialisers.** Swift synthesises only an internal memberwise initialiser for a public struct. So the types consumers build declare public memberwise initialisers: `SourceFileInput`, `ModuleInput` and the shared record shapes (`TypeKey`, `MemberKey`, `TypeCoupling`, `ModuleDependency`), which SwiftStats' index collector writes. Result types are built only by the library.

### 13.6 How the consumers call it

**SwiftProjectLint.**

- It already parses every file. For the complexity rules it calls `functionMetrics(of:)` on each `SourceFileInput`, with `options.complexity.decisionCountIgnoresTrivialSwitches = true` (§14.2). No module pass is needed.
- It compares `complexity.cognitive` with the threshold that `resultBuilderHint` selects, and `complexity.mccabe` with the decision-count threshold (§14.2). For each finding, the message lists the top increments: `items` filtered by metric, sorted by `amount`.
- For type and graph rules (§14.4) it groups its parsed files by target and calls `analyzeModule` once per target. It reads `TypeResult` for size, protocol and cohesion rules, and `typeEdges` for `circularDependency`, recomputing strongly connected components over the edges that rule keeps (§10.3). For `singleImplementationProtocol` it joins `TypeResult.conformances` across all its targets, test targets included (§9.5). No v1 rule needs `analyzePackage`.
- Pass 1 alone gives complexity only. Fan-out, common coupling, parameter counts and type targets all need pass 2, so a tool that wants them must hand the library every file of the module.

**SwiftStats.**

- It caches each `FileAnalysis` by content hash. It reruns `analyzeModule` when any file in the module changes. The module pass is cheap: the prototype took 0.8 s wall time for all of swift-collections, lookups included. `backfill` can therefore run all three passes per commit at T0. SwiftStats records the `MetricsVersion` (§13.4) with the collector (PRD §6.2), so a change of definition is never trended as a change of code. Syntactic and index values are never trended together (PRD §10).
- Per snapshot, for each module from its target resolution, it runs `analyzeFile` on each file whose cache entry is missing. The cache key is the file's content hash, the `MetricsVersion` and the `MetricsOptions`, because complexity is final in the file pass. It then runs `analyzeModule(name:isTest:files:)` per module and `analyzePackage` once.
- It leaves `decisionCountIgnoresTrivialSwitches` off and stores raw D. It sets `swiftLintIgnoresCaseStatements` from the package's `.swiftlint.yml`, as [PRD]:147 asks.
- It stores every record: each `FunctionRecord` with its `items`, each `TypeResult` with its components, each `TypeCoupling` and `ModuleCoupling`, with the `MetricsVersion` and options per snapshot (PRD §6.2).
- It maps kinds with `FunctionKind.swiftStatsKind`, and attaches `.propertyInitializer` records to their type ([PRD]:64).
- For comparisons with SwiftLint it sums SL over records where `swiftLintScoresKind` is true (§4.3), and records its own SwiftLint version beside `swiftLintReference`.

---

## 14. Thresholds and SwiftProjectLint rules

### 14.1 Principles

- A violation is "score greater than threshold", matching SwiftLint's `>` ([CCR]:101).
- SwiftProjectLint thresholds are hard-coded in each rule. A rule override changes only severity and excluded paths (`~/xcode_projects/SwiftProjectLint/Packages/SwiftProjectLintConfig/Sources/SwiftProjectLintConfig/Configuration/LintConfiguration.swift:61–69`). Re-basing a rule on a library count makes its threshold a plain number that can become configurable. It also gives SwiftStats the distribution below the threshold, which the adapter (PRD §7.15) never sees.
- The library reports values. The threshold, the severity, any exemption and the report wording belong to the rule (§1.2).

### 14.2 Complexity thresholds

The calibration sample was 19 real functions from swift-collections, swift-nio, SwiftStats and SwiftProjectLint, chosen to be complex, plus one control. It was scored by hand under the first draft's rules, with every SL value checked against SwiftLint 0.65.1. The figures below apply this specification's rules to it.

| Rule | Functions | Threshold | Severity | Reasoning |
|---|---|---|---|---|
| `cognitiveComplexity` | ordinary functions and accessors | 15 | warning | Sonar's default S3776 threshold is 15 ([S3776-API]; [JS] L45). It is the best-known value, and the score is built to match Sonar's scale. With the guard rule (row 16), 4 of the 19 sampled functions exceed 15: two correct flags and two borderline. A clear 28-line walker that scored 17 under the first draft now scores 15 and passes. |
| `cognitiveComplexity` | functions with `resultBuilderHint != .none`, including `.opaqueResult` | 30 | warning | Container closures add 1–4 nesting levels, so each `if` in a body costs 2–5. Example 6.9 scores 10. Kotlin raised `@Composable` to 45 ([Kotlin-check] L31–32, L42), and Rust's default is 30 ([S3776-API], rust). Start at 30 rather than 45, because `largeViewBody` and `viewBuilderComplexity` already push bodies to be short, and 45 would allow about ten deeply nested `if`s. The calibration has no evidence either way: the highest builder function it found scored 5. Set the final value from SwiftStats data (Q9). |
| `decisionCount`, compared as `mccabe` = D + 1 | all functions | 10 warning, 20 error | warning / error | D counts conditions the way NIST's v(G) does, so `mccabe` is v(G) ([NIST] §4.1). McCabe's limit is v(G) ≤ 10 ([NIST] §2.5), so warn at `mccabe > 10` (D > 9). Error at `mccabe > 20`: twice the limit, and above 15, the highest limit NIST reports in successful use. The numbers are not chosen for parity with SwiftLint. D runs well above SwiftLint's count on guard- and operator-heavy code (sampled pairs: 7 vs 1, 10 vs 5, 8 vs 5) and below it on switch code, so the same number would not flag the same functions. |

The choice to compare `mccabe` rather than D: McCabe's 10 is a limit on v(G), and comparing D > 10 would allow v(G) = 11, one more than the cited limit.

Effect on the calibration sample, with `decisionCountIgnoresTrivialSwitches` on:
- The 61-arm status-code table goes from D = 60 (an error) to D = 1.
- Warnings: the six-state WebSocket parser (D = 17), `performGroupOperation0` (D = 12), the Markdown block parser that once froze the app (D = 11), and three functions at exactly D = 10. The first draft's D > 10 passed those three. Each needs eleven basis-path tests, so the flag is fair on NIST's terms.

Recommendations for SwiftProjectLint:

- Ship `cognitiveComplexity` on by default.
- Ship `decisionCount` as opt-in, with `decisionCountIgnoresTrivialSwitches` on by default.
- Do not re-implement SwiftLint's rule as a lint rule. Users who want SwiftLint's numbers run SwiftLint. The compatible count exists for SwiftStats' comparisons ([PRD]:147).

For each finding, the linter's message can list the top increments from the breakdown (§13.3).

### 14.3 `viewBuilderComplexity`

**What it measures.**

[VBC] is `~/xcode_projects/SwiftProjectLint/Packages/SwiftProjectLintRules/Sources/SwiftProjectLintRules/Performance/Visitors/ViewBuilderComplexityVisitor.swift`.

- **Scope.** It checks `@ViewBuilder` functions and `@ViewBuilder` computed getters ([VBC]:18-58). It skips `body`, which the `largeViewBody` rule covers ([VBC]:36-37; [VBC-doc]:16).
- **Attribute matching.** The match is exact: an `IdentifierTypeSyntax` named `ViewBuilder` ([VBC]:90-99). So `@SwiftUI.ViewBuilder`, other result builders and builder closure parameters are missed.
- **What it measures.** Size only. It counts the lines of the body's description and its top-level statements ([VBC]:69-88).
- **When it fires.** When there are more than 30 lines or more than 15 statements ([VBC]:11-12).
- **What it ignores.** Branching, nesting and closures.

**Relationship to cognitive complexity.**

The two rules are orthogonal: one measures size, the other understandability. Keep `viewBuilderComplexity` as it is. Cognitive complexity does not replace it, and it does not duplicate it.

- A 40-line `VStack` with no branches trips `viewBuilderComplexity`, with C = 0.
- A 12-line body with nested `ForEach`/`if` can score high on C (example 6.9 scores 10) while passing the size rule.

The library's `resultBuilderHint` (§5) gives the linter its builder threshold. It also closes this rule's attribute-matching gaps, if the rule adopts it.

### 14.4 Coupling and cohesion rules

| Rule | What it measures now (source) | Library count | Recommendation |
|---|---|---|---|
| `fatProtocol` | Requirements ≥ 10; misses members inside `#if` (SPL/Architecture/Visitors/FatProtocolVisitor.swift:10, 31–44) | `requirementCount` (§9.1), which walks `#if` | **Re-base.** Fixes the `#if` gap. |
| `godViewModel` | `@Published` > 10 in an `ObservableObject` class, or stored `var` > 15 in `@Observable` (SPL/Architecture/Visitors/GodViewModelVisitor.swift:14–98) | `storedProperties` with `attributeNames`, `isLet`; `conformances` and `possibleSuperclass` (`ObservableObject` is first in the inheritance clause and outside the platform table); `customAttributes` | **Re-base the count.** The view-model test stays in the rule. |
| `fatViewDetection` | `@State`/`@StateObject` > 5 in a View (SPL/Architecture/Visitors/ArchitectureVisitor.swift:85, 129–135) | Stored properties by attribute | **Re-base.** |
| `tooManyEnvironmentObjects` | `@EnvironmentObject` ≥ 4 (SPL/StateManagement/Visitors/TooManyEnvironmentObjectsVisitor.swift:11, 43) | Stored properties by attribute | **Re-base.** |
| `circularDependency` | Two-type cycles over annotated stored properties in class and struct only. It skips parameters despite its doc comment (SPL/Architecture/Visitors/CircularDependencyVisitor.swift:84–88). It keys by simple name and loses edges after a nested type. | Module type graph (§10.3): SCCs of size ≥ 2, recomputed from `typeEdges` over `storedProperty` edges, excluding `isWeakOrUnowned` edges and protocol targets | **Re-base as a graph query.** It finds cycles of any length, not only pairs. It also fixes three other gaps: it covers every type kind, not only class and struct; it keys types by `TypeKey`, not by simple name; and it keeps edges after a nested type. The parameter gap stays, because the query reads `storedProperty` edges only. [PRD]:177 repeats the parameter claim and needs correcting. |
| `singleImplementationProtocol` | 0 or 1 production conformers; does not follow protocol inheritance (SPL/Architecture/Visitors/SingleImplementationProtocolVisitor.swift:46–75, 155–169) | Resolved conformances (`TypeResult.conformances`, §9.5) joined across every analysed module, test modules included, following protocol refinement. `conformerCount` alone is per module and misses test conformers | **Re-base the count.** The mock and fake exemption reads conformer names from the test modules. Exemptions stay in the rule. |
| `nestedGenericComplexity` | Generic parameters > 3, nesting > 2, `where` requirements > 3 (SPL/CodeQuality/Visitors/NestedGenericComplexityVisitor.swift:13–80). It is not in `optInRules` (LintConfiguration.swift:107–148), and nothing in its visitor says whether it should be. | Generic signature counts (later set, §11.1) | **Re-base when the later count lands.** Decide whether it is opt-in and make `optInRules` match. |
| `wideReachThrough` | Distinct members read from one receiver ≥ 3, with an idiom filter (SPL/Architecture/Visitors/WideReachThroughVisitor.swift:26–36) | Foreign members per receiver (later set) | **Keep as is for v1.** Re-base later; the idiom filter stays in the rule. |
| `lawOfDemeter` | Chains ≥ 3 dots through a tuned exemption filter (SPL/Architecture/Visitors/LawOfDemeterVisitor.swift:35; DemeterChainFilter.swift:110–137) | None | **Keep as is.** Its definition is the exemption list. |
| `singletonUsage` | `X.shared` on service-suffixed names (SPL/Architecture/Visitors/SingletonUsageVisitor.swift:33–49) | `singletonRefs` (census only) | **Keep as is.** It is a per-site naming rule. |
| `globalMutableState` | Each static or file-scope stored `var` (SPL/Testability/Visitors/GlobalMutableStateVisitor.swift:31–66) | Module global declarations; `mutableGlobalRefs`, `mutableStaticRefs` (census) | **Keep as is.** |
| `directInstantiation` | `T(...)` of service-suffixed types with about 10 exemptions (SPL/Architecture/Visitors/DirectInstantiationVisitor.swift:50–214) | `body` edges per function; constructed-type count (later set) | **Keep as is.** Its composition-root sub-test could read the later count. |
| `concreteTypeUsage`, `missingDependencyInjection`, `accessingImplementationDetails` | Naming and policy heuristics | `ceConcrete` / `ceProtocol` as context only | **Keep as is.** |
| `undeclaredTargetDependency`, `unusedTargetDependency` | Manifest compared with imports (SPL/Architecture/Visitors/UndeclaredTargetDependencyVisitor.swift:45–72) | Import facts (§10.1) | **Keep as is.** They may read the shared import facts. |
| `layerDependency`, `architecturalBoundary` | Forbidden references across configured layers | Shared type-reference extractor (§7.3) | **Keep as is.** Read the shared extractor instead of their own. |
| `booleanControlCoupling` | `Bool` parameter selecting two substantial paths (SPL/Architecture/Visitors/BooleanControlCouplingVisitor.swift:303) | None in v1 | **Keep as is.** |
| `multipleTypesPerFile` | More than one top-level type per file | None | **Keep as is.** It is not coupling. |

No rule is retired. Every coupling rule either measures something the library does not, or carries policy (suffixes, exemptions, layer configuration) that belongs in the linter. SwiftProjectLint currently has four separate type-reference extractors that disagree:

- `CircularDependencyVisitor.extractTypeName` (:163–177)
- `DependencyConsumption.baseTypeNames` (SPL/Architecture/Visitors/DependencyConsumption.swift:17–33)
- `TypeReferenceCollector` (SPL/Architecture/Visitors/LayerDependencyVisitor.swift:65–92)
- `ArchitecturalBoundaryVisitor.visit(IdentifierTypeSyntax)` (:68)

Replacing them with the §7.3 extractor is the largest single gain.

PRD D4 ([PRD]:486), "SwiftProjectLint is the source of truth", should become: SwiftCodeMetrics owns the count, and SwiftProjectLint owns whether it is a defect.

### 14.5 New rules

| Rule | Library value | Default | Fires when | Defined in |
|---|---|---|---|---|
| `cognitiveComplexity` | `complexity.cognitive` | on | > 15; > 30 when `resultBuilderHint != .none` (warning) | §14.2 |
| `decisionCount` | `complexity.mccabe`, with `decisionCountIgnoresTrivialSwitches` on | opt-in | > 10 (warning); > 20 (error) | §14.2 |
| `lowCohesionType` | `cohesion.lcom4` and `cohesion.components` | opt-in | LCOM4 ≥ 2 and each counted component has ≥ 3 members; types with `hasKnownAttachedMacro` skipped | §9.3, Q31 |

No rule repeats SwiftLint's `cyclomatic_complexity` (§14.2) or `function_parameter_count` (§8.3).

---

## 15. Open questions

Each question has a recommendation the owner can accept or overturn. Questions marked "Decided" or "Closed" record a choice already made, so it can be overturned with its reasons in view.

### 15.1 Shared definitions and API

**Q1. Who renders the function key, and which records exist?**
- Part B's records carry SwiftStats' syntactic key (PRD §6.1). SwiftStats renders that key today in its own collector (`~/xcode_projects/SwiftStats/Sources/SwiftStatsCore/Functions/FunctionCollector.swift`, with `CanonicalText` and `DeclarationRenderer`). Two renderers will drift.
- The record sets differ in one place. SwiftStats emits a `subscript` record for every subscript with a body, plus an `accessor` record for each explicit accessor. The library emits a `.subscriptGetter` record for an implicit getter, and only the accessor records otherwise (§2.1).
- **Recommendation:** the library renders the key, by the PRD §6.1 rules, so both consumers agree on identity. Before SwiftStats switches, a test compares the two renderers on its corpora and must find no difference. SwiftStats keeps its `subscript` record as a grouping record with no scores, and takes the subscript's parameter counts from the record that carries them (§8.3).
- **Status: open.** The record-set difference needs the owner's decision. Until then this recommendation stands: the library renders the key, and SwiftStats keeps its `subscript` grouping record.

**Q2. How should `#if` be counted?**
- Every metric walks every clause (§2.6). C counts every clause, with `#if` structural and `#elseif`/`#else` hybrid. D takes the maximum. SL sums. Part B takes the union of branches, with conditions recorded, and WMC uses the maximum per member.
- **Recommendation:** keep this split for v1, consistent with PRD §6.1a. The reader reads every clause, but a build runs one. Add an optional `BuildConfiguration` parameter later, through `SwiftIfConfig`, for single-build values.
- The calibration saw a two-line `#if os(Windows)` shim in a case body cost 3. Making `#else` free would save only 1 there. Revisit with SwiftStats data on NIO-style code.
- The union can join cohesion groups that never coexist in one build (§9.3, known error modes).

**Q3. How should macros be treated?**
- **Recommendation for attached macros:** measure the source as written, set `hasKnownAttachedMacro`, and have SwiftProjectLint skip cohesion thresholds for such types. Expanding macros needs built plugins, which breaks the syntax-only rule.
- **Recommendation for freestanding macros:** count their arguments as written, in every metric (§2.7; §3.2 row 62). They are source the reader reads. `#expect(a && b)` in tests will add +1. That is fair, and tests are usually reported separately.

**Q4. How should definition changes be versioned?**
- **Recommendation:** expose two definition versions in `MetricsVersion` (§13.4): `complexityDefinition`, a string such as `"complexity-1"`, and `couplingDefinition`, such as `"coupling-1"`. Bump the number for any change that alters a value, including a change to a default option. Report the platform table's SDK version beside them. SwiftStats stores all of them with each snapshot, so history stays comparable, and a change of definition is never trended as a change of code.

**Q5. How should broken source be handled?**
- **Recommendation:** skip `UnexpectedNodesSyntax` children and set `hasSyntaxErrors`. Do not refuse to score.

**Q6. What about code outside function bodies?**
- This covers stored-property initial values (`lazy var x = { … }()`), closures in default parameter values, and top-level code.
- **Recommendation:**
  - A stored-property initial value becomes a `.propertyInitializer` function when its C or D would be non-zero. A constant initial value is not logic anyone reads, and one record per stored property would swamp the per-function data. This applies to top-level types (file walker, or `functionMetrics(of:)` on the type) and local types (linked to the enclosing function). It never folds into the enclosing function's C or D. It does fold into its SL, as SwiftLint does.
  - Top-level code becomes one `.topLevelCode` function per file, emitted only by the file walker and only for a file with top-level statements (statements that are not declarations). SwiftStats needs it for its synthetic per-file record ([PRD]:70).
  - Global variables and `static` stored properties are treated like instance stored properties: a `.propertyInitializer` record when C or D is non-zero (§2.1).
  - Default-value closures stay unscored. SwiftLint ignores them too.
  - SwiftProjectLint can ignore both new kinds. The PRD attaches results outside a function body to the enclosing type or file ([PRD]:64).
  - A `.propertyInitializer` record carries complexity only. It gets no function-level coupling and is not a WMC term. Its type names count towards its type's Ce (§2.1). If SwiftStats data later shows that initial values carry real logic, adding them to WMC is a definition change (Q4).

### 15.2 Part A: complexity

**Q7. Should `guard` be cheaper than `if`?** (Decided.)
- The options were: free (Kotlin `?: return`), +1 flat (fundamental), or structural.
- **Decision:** +1 fundamental, with the `else` body still raising nesting (row 16). In the calibration, nested guards made up 14 of 23 points in a regular parser, 7 of 12 in a group-operation function, and 3 of 17 in a clear walker.
- **Cost:** a nested `guard c else { return }` and `if !c { return }` no longer score the same. The gap appears only when nested, and it favours the idiomatic Swift form. Top-level guards are unchanged.
- "Free" was rejected: it would take a validator with five real rejection rules from 8 to 3.
- The breakdown tags guard increments, so SwiftStats can recompute either alternative from stored data.

**Q8. How should a condition list count?** (Decided.)
- **Decision:** +1 once for a list of two or more elements, and each `.expression` element is its own root sequence (row 17). Under the first draft's comma-as-`&&` rule, a list's score depended on element order (example 6.18; calibration `isXCTestMethod`: 4 or 3 by order).
- `prefer_condition_list` stays neutral for pure `&&` runs: `if a && b && c` and `if a, b, c` both cost +1. A partial rewrite such as `if a && b, c` costs +2, one more than `if a && b && c`. That is accepted: it mixes two forms of conjunction.

**Q9. Should builder container closures be discounted?**
- `VStack { HStack { … } }` nests through closures that read as layout.
- **Recommendation:** no discount in the metric, because builder closures cannot be identified without types. Use the builder threshold (§14.2). Set it from SwiftStats data, for example at the 95th percentile of builder functions across the corpora.
- A "closure in tail position does not nest" rule (`return self.read { … }`, the outer container of `body`) was considered and rejected for v1. It would take one sampled function from 18 to 12, but chained modifiers make "tail position" hard to define. `Increment.closureNesting` records how much nesting comes from closures, so SwiftStats can test the idea on stored data.
- `closureNesting` counts `ClosureExprSyntax` levels only. `defer` bodies raise nesting (row 8) but are not counted in it: they are statements, not closures, and neither a builder discount nor a tail-position rule would apply to them. Example 6.9 has no `defer`, so its "5 of the 6" is unaffected.

**Q10. How far should recursion detection go?**
- **Recommendation:** direct recursion only, matched by base name and labels, with unqualified or `self` receivers, and `Self` only in static functions (§3.4).
- Accept the false negatives: calls through another instance (tree code such as `node.left.depth()`) and indirect cycles. They are flagged with zero-amount `possibleRecursion` items.
- Accept the false positives from overloads that share a base name and labels.
- Revisit if SwiftStats adds an index-based call graph.

**Q11. Do plain parentheses join the surrounding sequence?** (Closed.)
- **Answer:** yes (row 50). Sonar Java skips parentheses when it flattens a logical expression ([Java] L300–301). Only a prefix operator's operand starts a new sequence, which is the paper's `a && !(b && c)` case [CC p.8].

**Q12. Where does a nested function's nesting start?**
- **Recommendation:** at 0. It is scored on its own and should read like any other function. C# static local functions keep +1 inside ([CSharp-tests] Latest.cs L212–225). This library does not.

**Q13. Should the `else` of an `if` expression be free, as in Kotlin?**
- **Recommendation:** no. Count the expression and statement forms the same, to keep refactors neutral. A ternary remains the cheap form (+1).

**Q14. Should optional chaining count in the decision count?**
- **Recommendation:** no. If wanted, report `optionalChainLinks` as a separate statistic in SwiftStats.

**Q15. Should `??` count in the decision count?**
- **Recommendation:** yes, +1 each. It is a real conditional edge and chains are rare. Cognitive complexity keeps ignoring it.

**Q16. What happens when Sonar ships Swift cognitive complexity?**
- Campbell targeted it for the new analyser, with no date given ([Forum-183000]).
- **Recommendation:** when it ships, run both tools on the worked examples. Then align any rule where Sonar documents a Swift choice and this specification has no stated reason to differ. Keep the differences listed in the README.

**Q17. Should lookup-table switches be discounted?**
- **Recommendation:** only in the lint, through `decisionCountIgnoresTrivialSwitches` (§4.2). The raw D stays the NIST count, as NIST §2.5 advises. SwiftLint's `ignores_case_statements` is the analogue for SL.

### 15.3 Part B: coupling and cohesion

**Q18. Move LCOM and module coupling from T1 to T0 in PRD §7.6?**
- **Recommendation:** yes. Update [PRD]:170–177 and D4 ([PRD]:486). Keep the index versions as cross-checks with `provenance: index`. Also correct [PRD]:177's claim that `circularDependency` uses parameters.

**Q19. Exclude `init` and `deinit` from the cohesion graph?**
- **Recommendation:** yes. Including them changed `SitrepFileVisitor` from 2 to 4 and would join every struct's groups. Report them in `excludedMembers`.

**Q20. Treat whole-`self` use as touching every attribute?**
- **Recommendation:** yes for structs, no for classes and actors. Enums have no attributes, so the question does not arise for them. It removed a large share of false splits in value types (for example 40.6% → 26.6% LCOM4 > 1 in swift-collections). It is wrong for reference types, where `self` is identity.

**Q21. Exclude `description`, `debugDescription` and `customMirror` by default?**
- **Recommendation:** yes, with an option to include them. They usually read every field, like `hash(into:)`. A non-witness member with the same name is wrongly excluded; that is rare and documented.

**Q22. Drop attribute-free components from LCOM4?**
- **Recommendation:** yes, and always list them in `isolatedMembers`. It extends Aivosto's empty-method convention to chains of members that never reach state. It took LCOM4 > 1 from 9–31% to 1–5% in the prototype. Part of that drop is the LCOM4 ≤ |A| bound it introduces, so corpus figures must be read over types with |A| ≥ 2.

**Q23. Call keys: keep argument labels despite default-argument splits?**
- **Recommendation:** keep labels. They distinguish real overload families (`append(_:)` versus `append(contentsOf:)`). The split is a known overcount of 4–6% in the spot checks. Collapsing to base names would hide more than it fixes.

**Q24. Instability from `cePackage` or `ceAll`?**
- **Recommendation:** `cePackage`. Ca can only be counted within the scanned packages, so both sides should use the same boundary. Report `ceAll` beside it.

**Q25. Depend on SwiftLexicalLookup despite its SPI scope conformances?**
- **Recommendation:** yes. Use only the public `lookup(_:with:)`, behind one internal resolver type with its own tests: shadowing, shorthand binding, closure parameters, capture lists, `.lookForGenericParameters` in extensions, `.lookForImplicitClosureParameters` in parameterless closures, and a nil identifier. If a swift-syntax upgrade changes behaviour, the resolver is the only place to fix. The fallback is a hand-written scope walk.

**Q26. Where do the Foundation names that are not in the swiftinterface come from?**
- **Recommendation:** a line scan, made by the platform-table generator (§7.4), of `Foundation.apinotes` (`SwiftName:` under `Typedefs:` and `Tags:`) for types such as `Decimal` and `TimeInterval`, and of `FOUNDATION_EXPORT` functions in the Foundation headers for free functions such as `NSDecimalRound`. Objective-C classes use the `^NS[A-Z]` fallback in files that import Foundation or a module known to re-export it. A full Clang parse is out of scope, and a module's own `NS…` type still wins because module declarations shadow the table.

**Q27. Emit `caWithinModule` before the index exists?**
- **Recommendation:** yes, with `provenance: syntax` and `resolution: approximate`. It is as accurate as `ce` within the module. Type-level instability needs it. The index replaces it at M7 without key changes.

**Q28. Associated-type names that collide with top-level module types.**
- **Recommendation:** accept the false edge in v1 and count it in tests on the corpora. If it matters, use the platform table's `associatedtype` names to suppress `Element`, `Index`, `Iterator`, `SubSequence` and the like inside types that conform to the declaring protocol.
- **v0.3 corpus report (2026-11-17).** Distinct unresolved and ambiguous type names, summed over types: swift-collections 15 and 0, swift-nio 1 and 75, GRDB 23 and 10, TCA 23 and 0, SwiftProjectLint 1 and 0, SwiftStats 0 and 0. The false edges this question describes are not counted separately; they resolve, so they appear as ordinary module edges.

**Q29. Should the library define `ChangeCouplingPair`?**
- **Recommendation:** no. Only SwiftStats' history collector produces and consumes it, so it stays in SwiftStats. The library defines the static-edge shapes (`TypeCoupling`, `ModuleDependency`), which two producers share: the library and the index collector.

**Q30. Count test modules in module Ca?**
- **Recommendation:** no. Report `caTests` separately. Tests importing a module say nothing about its production dependents.

**Q31. A `lowCohesionType` rule in SwiftProjectLint.**
- **Recommendation:** add it as opt-in. Fire when LCOM4 ≥ 2 and each counted component has ≥ 3 members. Skip types with `hasKnownAttachedMacro`. Calibrate k on the six corpora, over types with |A| ≥ 2, before turning it on by default.
- **v0.3 corpus report (2026-11-17).** Types with LCOM4 > 1 over types with |A| ≥ 2: swift-collections 4 of 105 (3.8%), swift-nio 16 of 291 (5.5%), GRDB 12 of 195 (6.2%), TCA 4 of 96 (4.2%), SwiftProjectLint 1 of 38 (2.6%), SwiftStats 1 of 27 (3.7%). The modules are each corpus's `Sources/<target>` directories (GRDB's `GRDB` directory). k is not yet calibrated.

**Q32. Subclasses of module classes: inherit attributes, or null?**
- **Recommendation:** inherit (§9.3), with `attributeCount` reported beside `noa`. The alternative is a null reason `inheritsModuleState`. It is simpler, but it leaves every such subclass unmeasured, and it would hide a subclass that really does split.

### 15.4 Adoption

**Q33. PRD D3 says SwiftStats links only SwiftEffectInference.**
- D3 ([PRD]:485) keeps SwiftStats' package graph small and reads every other tool through its output files. SwiftCodeMetrics has no output files: it is a library.
- **Recommendation:** amend D3 to "link SwiftEffectInference and SwiftCodeMetrics". Both pin swift-syntax `exact: "603.0.2"`, so the package graph still resolves. Amend D4 at the same time (§14.4) and move LCOM and module coupling to T0 (Q18).
- **Status: drafted in PRD v0.2.2** (D3, D4, §7.3, §7.6), pending the owner's review of this specification.

---

## 16. Implementation milestones

Each milestone is a tagged release of the library. Each one builds in Swift 6 language mode with no warnings, and passes its tests with `swift test` after `swift package clean`.

### v0.1: complexity only

**Scope.**

- The package: one library product, `SwiftCodeMetrics`, depending on `SwiftSyntax` only. Test dependencies: `SwiftParser`, `SwiftOperators` and Swift Testing.
- Function discovery by §2.1: every kind, keys, names, parent links, and one record per `#if` variant.
- The three per-function scores of Part A, with their itemised breakdowns: C (§3), D and `mccabe` (§4.1–4.2), and SL (§4.3). Also `maxNesting`, `resultBuilderHint` (§5) and `hasSyntaxErrors` (§2.8).
- `functionMetrics(of:)`, both forms. `ComplexityOptions`. `MetricsVersion` with `complexityDefinition = "complexity-1"`.

**Done when:**

- **Golden tests.** Every worked example in §6 (6.1–6.18) and the worked check in §4.2 is a fixture. Each fixture asserts C, D, `mccabe` and SL for every record it contains, and the anchor line of every item. Example 6.13 is also asserted with `decisionCountIgnoresTrivialSwitches` on (D = 3).
- **Breakdown invariant.** For every fixture and metric, the sum of `amount` over that metric's items equals the score.
- **Construct coverage.** Every row of the §3.2 construct table and the §4.2 decision table has at least one test.
- **Folded input.** Each fixture, folded with `SwiftOperators`, gives the same C and D as the unfolded tree (§3.5.1).
- **SwiftLint parity.** A test runs SwiftLint 0.65.1 with `only_rules: [cyclomatic_complexity]` and `warning: 0` on every fixture, the Appendix A probes included, and on the Swift sources of SwiftStats, SwiftProjectLint and swift-collections. For every `func` and `init`, SL equals the number SwiftLint reports, and 0 where SwiftLint reports nothing. It also runs with `ignores_case_statements: true`. There are no mismatches. The test is skipped, with a message, when the `swiftlint` binary is missing or is not 0.65.1.
- **Codable.** A `FunctionAnalysis` for every fixture survives an encode and decode round trip unchanged.

### v0.2: per-function coupling

**Scope.**

- The `SwiftLexicalLookup` dependency, behind one internal resolver type (Q25). It brings in `SwiftIfConfig`, `SwiftParser`, `SwiftOperators`, `SwiftSyntaxBuilder` and `SwiftDiagnostics` as indirect dependencies (§1.3).
- The file pass and the module pass (§7.1), for name resolution only: extension merging into the module symbol table (§2.2), value names (§7.2), type names (§7.3), the platform table and its generator (§7.4), and call keys (§7.5). Merging is needed already, because own members (§7.2), nested types (§7.3) and the `self`/`implicit` split (§8) can come from extensions in other files.
- The function-level metrics of §8: `fanOut` and its splits, common coupling, and parameter counts. `typeReferences` resolved.
- `analyzeFile` and both forms of `analyzeModule`, returning function records with coupling. `ModuleAnalysis.types` is still empty. `couplingDefinition = "coupling-1"`; `platformTable` set.

**Done when:**

- **Golden tests.** The function-level values stated in §12.1–12.5 (fan-out with its separate counts, common coupling, parameter counts) are asserted exactly.
- **Resolver tests.** Each case listed in Q25 has a test: shadowing, shorthand binding, closure parameters, capture lists, `.lookForGenericParameters` in extensions, `.lookForImplicitClosureParameters` in parameterless closures, and a nil identifier. The four real cases in §7.2 are reproduced.
- **Platform table.** The table generated from SDK 27.2 classifies `JSONDecoder`, `DispatchQueue`, `Decimal` and `TimeInterval` as platform types, `NSDecimalRound` and `NSLog` as platform free functions, and `XCTAssertEqual` as a platform free function only in files that import XCTest.
- **Corpus checks.** The function-level figures in §12.7 are reproduced: `SyncUpDetail.body` (6 pattern-position sites excluded; headline 8, `fanOutImplicitMember` 6, `fanOutChained` 1), `ContentView.decoratedMainStack` (headline 8, `fanOutChained` 7), `singletonRefs` 0 in `Heap.popMin`, and the one `RuleSelectionWindowController.shared` reference in `ContentView`.
- **Caching.** `analyzeModule(name:isTest:files:)` over decoded `FileAnalysis` values gives the same `ModuleAnalysis` as `analyzeModule(_:)` over the trees.
- **Speed.** The module pass over all of swift-collections takes under 2 s wall time on the development machine. The prototype took 0.8 s.

### v0.3: per-type and per-module coupling

**Scope.**

- Type records for merged types, extension groups and `unresolvedExtensions` (§2.2). Extension merging into the symbol table arrives in v0.2.
- The type-level metrics of §9: the type record and sizes, `wmcCognitive` and `wmcDecisions` from the v0.1 scores, `lcom4` with its components and null reasons, `ce` with its splits and `ceFamily`, `caWithinModule` and `conformerCount`.
- The module-level metrics of §10: import facts, the type graph and its cycles, and `analyzePackage` with module Ce, Ca and instability.

**Done when:**

- **Golden tests.** Every type and module value stated in §12.1–12.6 is asserted, including each step's components, `isolatedMembers`, `unusedAttributes` and null reasons, and the §12.6 table.
- **Invariants.** `ce` = `ceProtocol` + `ceView` + `ceNamespace` + `ceConcrete` for every type. `instanceMembers` + `staticMembers` = `nom`. `lcom4` ≤ |A| whenever it is not null. Each null reason in §9.3 has a test that hits it first.
- **Corpus checks.** The "Part B" column of the §12.7 table is reproduced for all seven types.
- **Corpus report.** A test reports the share of types with LCOM4 > 1 over types with |A| ≥ 2 for the six corpora, and the counts of `unresolvedTypeRefs` and `ambiguousTypeRefs`. The figures are recorded for Q31 and Q28.

### Adoption by SwiftStats

**Scope.** SwiftStats calls the library as §13.6 says, from v0.1 for complexity and from v0.3 for coupling. PRD §7.3 and §7.6 are updated to cite this specification, with Q18 and Q33 applied.

**Done when:**

- A `backfill` over SwiftStats' own history stores every function, type and module value per commit, with the `MetricsVersion` and options of each run.
- A change of `complexityDefinition`, `couplingDefinition` or `platformTable` shows in a trend as a definition break, not as a change of code.
- For sampled snapshots, SL on every record with `swiftLintScoresKind` equals the value SwiftLint 0.65.1 reports for that `func` or `init` when run with `warning: 0`, as in the v0.1 parity test.
- Missing values are stored as null, never 0 (PRD §6.5). The key comparison in Q1 finds no difference.

### Adoption by SwiftProjectLint

**Scope.** SwiftProjectLint adds `cognitiveComplexity` and `decisionCount` (§14.2) from v0.1. From v0.3 it re-bases the rules marked "Re-base" in §14.4, replaces its four type-reference extractors with the library's (§14.4), and adds `lowCohesionType` as opt-in (Q31).

**Done when:**

- Each re-based rule passes its existing tests, plus a new test for each gap §14.4 says it fixes: `#if` members in `fatProtocol`; in `circularDependency`, cycles longer than two, cycles through enums and actors, two types with the same simple name in different scopes, and an edge declared after a nested type; and protocol inheritance and test-module conformers in `singleImplementationProtocol`.
- The four extractors are gone, and `layerDependency` and `architecturalBoundary` read the library's type references.
- A run over SwiftProjectLint's own sources gives a findings diff that has been reviewed, with every new or lost finding explained.
- PRD D4 has the wording in §14.4.

After both adoptions, the library is tagged 1.0 once a release cycle passes with no breaking API change.

---

## 17. References

Labels are used throughout. Paths follow §1.5.

### 17.1 Cognitive complexity and Sonar

- **[CC]** G. Ann Campbell, *Cognitive Complexity: a new way of measuring understandability*, v1.7, 29 August 2023. https://www.sonarsource.com/docs/CognitiveComplexity.pdf (page numbers are PDF pages; not re-verified in this specification).
- **[S3776-API]** SonarQube Cloud rules API, queried 2026-11-17: https://sonarcloud.io/api/rules/show?key=swift:S3776&organization=sonarsource (also `rust:S3776`, `csharpsquid:S3776`).
- **[S3776-archive]** https://web.archive.org/web/20250806114049/https://rules.sonarsource.com/swift/rspec-3776/
- **[Forum-172187]** https://community.sonarsource.com/t/new-swift-analyzer-with-support-swift-6-2-swiftui-and-22-sast-rules/172187
- **[Forum-179778]** https://community.sonarsource.com/t/cognitive-complexity-for-ios-swift-mobile-app-code/179778
- **[Forum-183000]** https://community.sonarsource.com/t/cognitive-complexity-for-swift-projects/183000
- **[SLang]** https://github.com/SonarSource/slang/blob/8a8154f8ef0beba7c23e2f4ce830dfe71dfa3aa7/slang-checks/src/main/java/org/sonarsource/slang/checks/complexity/CognitiveComplexity.java
- **[Kotlin]** https://github.com/SonarSource/sonar-kotlin/blob/336671e5838d43b4687378a5ba070480ecee68f9/sonar-kotlin-checks/src/main/java/org/sonarsource/kotlin/checks/CognitiveComplexity.kt ; **[Kotlin-check]** `FunctionCognitiveComplexityCheck.kt` in the same directory at the same commit (`336671e5`): `DEFAULT_THRESHOLD = 15` and `COMPOSABLE_THRESHOLD = 45` at L31–32, the `@Composable` test at L42 (checked 2026-11-17).
- **[Go]** https://github.com/SonarSource/sonar-go/blob/94427dafd85d5cdf0ec62b66d0c24bf443ba5892/sonar-go-checks/src/main/java/org/sonar/go/checks/complexity/CognitiveComplexity.java ; **[Go-tests]** `CognitiveComplexityTest.java` at the same commit.
- **[Rust]** https://github.com/SonarSource/sonar-rust/blob/76876992e964aadbbe80a40e88c1a31b881a727b/analyzer/src/visitors/cognitive_complexity.rs
- **[CSharp]** https://github.com/SonarSource/sonar-dotnet/blob/a0cf5c69e85265f64d6f60aa8de0bda9a815df3c/analyzers/src/SonarAnalyzer.CSharp/Metrics/CSharpCognitiveComplexityMetric.cs ; **[CSharp-tests]** `analyzers/tests/SonarAnalyzer.Test/TestCases/CognitiveComplexity.cs` and `CognitiveComplexity.Latest.cs` at the same commit.
- **[JS]** https://github.com/SonarSource/SonarJS/blob/b81f523a4be0e8b9fa2bd7105ce35dc18b319ffd/packages/analysis/src/jsts/rules/S3776/rule.ts
- **[Java]** https://github.com/SonarSource/sonar-java/blob/f326b5f16719fcb2aa3bb2f7c4df072ef949079e/java-frontend/src/main/java/org/sonar/java/ast/visitors/CognitiveComplexityVisitor.java. Lines used: L133–143 (local-class methods fold), L169–188 (`if`: condition before the level rises; L175–183 flat `else if`), L191–198 (`try`), L234–239 (conditional expression), L250–262 (labelled jumps), L273–277 (lambdas), L295–306 (logical-expression flattening; `skipParentheses` at L300–301).
- **[Sonar-metrics]** https://docs.sonarsource.com/sonarqube-server/latest/user-guide/code-metrics/metrics-definition/

### 17.2 Decision count

- **[NIST]** A. Watson and T. McCabe, NIST SP 500-235, 1996. https://www.mccabe.com/pdf/mccabe-nist235r.pdf (§2.2, §2.5, §4.1).
- **[McCabe76]** T. McCabe, "A Complexity Measure", IEEE TSE SE-2(4), 1976. doi:10.1109/TSE.1976.233837
- **[Lizard]** https://github.com/terryyin/lizard (`lizard_languages/swift.py`, `swift_conditions.py`; read, not run).

### 17.3 Coupling and cohesion

- **[CK91]** Chidamber & Kemerer, OOPSLA 1991, https://doi.org/10.1145/117954.117970
- **[CK94]** Chidamber & Kemerer, IEEE TSE 20(6), 1994, https://doi.org/10.1109/32.295895
- **[HM95]** Hitz & Montazeri 1995, Proc. Int. Symp. Applied Corporate Computing, as reproduced at https://aivosto.com/project/help/pm-oo-cohesion.html and https://metacpan.org/pod/Analizo::Metric::LackOfCohesionOfMethods
- **[HM96]** Hitz & Montazeri, IEEE TSE 22(4), 1996, https://doi.org/10.1109/32.491650
- **[BK95]** Bieman & Kang, ACM SSR 1995, https://doi.org/10.1145/211782.211856
- **[Briand97]** Briand, Daly & Wüst, cohesion framework, https://doi.org/10.1109/METRIC.1997.637164
- **[Briand99]** Briand, Daly & Wüst, coupling framework, https://doi.org/10.1109/32.748920
- **[ElEmam01]** El Emam et al., IEEE TSE 27(7), 2001, https://doi.org/10.1109/32.935855
- **[HK81]** Henry & Kafura, IEEE TSE SE-7(5), 1981, https://doi.org/10.1109/TSE.1981.231113
- **[Martin94]** Martin, "OO Design Quality Metrics: An Analysis of Dependencies", 1994
- **[Martin02]** Martin, Agile Software Development, 2002, ch. 20
- **[SMC74]** Stevens, Myers & Constantine, IBM Systems Journal 13(2), 1974, https://doi.org/10.1147/sj.132.0115
- **[LM06]** Lanza & Marinescu, Object-Oriented Metrics in Practice, Springer 2006

### 17.4 Swift

- **[Swift-Ext]** Swift book, Extensions: https://docs.swift.org/swift-book/documentation/the-swift-programming-language/extensions/
- **[SE-0099]** https://github.com/swiftlang/swift-evolution/blob/main/proposals/0099-conditionclauses.md
- **[SE-0166]** Swift Archival & Serialization: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0166-swift-archival-serialization.md
- **[SE-0185]** Synthesizing Equatable and Hashable conformance: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0185-synthesize-equatable-hashable.md
- **[SE-0258]** Property Wrappers: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0258-property-wrappers.md
- **[SE-0286]** https://github.com/swiftlang/swift-evolution/blob/main/proposals/0286-forward-scan-trailing-closures.md
- **[SE-0306]** Actors: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0306-actors.md
- **[SE-0345]** `if let` shorthand: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0345-if-let-shorthand.md
- **[SE-0380]** `if` and `switch` expressions: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0380-if-switch-expressions.md
- **[SE-0389]** Attached Macros: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0389-attached-macros.md
- **[SE-0395]** Observation: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0395-observability.md

### 17.5 swift-syntax 603.0.2

- Node definitions in `N/` and parser sources in `P/`, cited inline. Also `Sources/SwiftSyntax/generated/SyntaxCollections.swift:460`, `Sources/SwiftSyntax/AbsolutePosition.swift:15`, `Sources/SwiftOperators/OperatorTable+Defaults.swift:70-86`, `Sources/SwiftOperators/OperatorError.swift:32` and `Sources/SwiftIfConfig/ConfiguredRegions.swift:97`.
- SLL/Scopes/ScopeSyntax.swift:14–48; SLL/LookupResult.swift:16–47 (the four cases at :18, :20, :34, :47) and :77–81; SLL/Scopes/ScopeImplementations.swift:34–61, :186–194, :386 and :405–420. `TokenSyntax.identifier` at `Sources/SwiftSyntax/TokenSyntax.swift:152`.
- The first complexity draft cited a swift-syntax inventory as "[SS-inv]" with no path. Its facts are now cited directly to `N/` and `P/` lines, or marked as checked with the parse-tree dumper.

### 17.6 SDK

- **SDK** (SDK 27.2): the `Swift`, `_Concurrency`, `_StringProcessing`, `Dispatch` and `Foundation` `arm64e-apple-macos.swiftinterface` files and the XCTest interface, at the paths in §7.4; `Foundation.framework/Headers/Foundation.apinotes`; `NSDecimal.h:53, :76`; `NSDate.h:22`.

### 17.7 SwiftLint

- **[CCR]** `~/GitHub_projects/SwiftLint/Source/SwiftLintBuiltInRules/Rules/Metrics/CyclomaticComplexityRule.swift` (commit ec4691d9e8). **[CCC]** `…/Rules/RuleConfigurations/CyclomaticComplexityConfiguration.swift`. **[VSV]** `~/GitHub_projects/SwiftLint/Source/SwiftLintCore/Visitors/ViolationsSyntaxVisitor.swift`. Probes ran against SwiftLint 0.65.1.
- `~/GitHub_projects/SwiftLint/Source/SwiftLintBuiltInRules/Rules/RuleConfigurations/FunctionParameterCountConfiguration.swift:6–8` (§8.3).

### 17.8 Project files

- **[PRD]** `~/xcode_projects/SwiftStats/Docs/PRD.md`: §6.1 lines 49–64 (the key at :53, results outside a function body at :64), §6.1a :66–75, §6.2–6.4 :77–108, §6.5 :110–116, §7.2 :135–142, §7.3 :145–149, §7.6 :170–177, §7.13 :301–317, §8 :360–390, §14 :479–495 (D3 at :485, D4 at :486, Q3 at :494).
- `~/xcode_projects/SwiftStats/Sources/SwiftStatsCore/Model/FunctionKind.swift:12–26`; `~/xcode_projects/SwiftStats/Sources/SwiftStatsCore/Functions/FunctionCollector.swift:238–254`.
- **[VBC]** `~/xcode_projects/SwiftProjectLint/Packages/SwiftProjectLintRules/Sources/SwiftProjectLintRules/Performance/Visitors/ViewBuilderComplexityVisitor.swift` ; **[VBC-doc]** `~/xcode_projects/SwiftProjectLint/Docs/rules/view-builder-complexity.md`.
- SwiftProjectLint rule files, cited in §14.4. `~/xcode_projects/SwiftProjectLint/Packages/SwiftProjectLintConfig/Sources/SwiftProjectLintConfig/Configuration/LintConfiguration.swift`.
- Package manifests cited in §1.2.
- Corpora: swift-collections, swift-nio, GRDB.swift and swift-composable-architecture under `~/GitHub_projects/`, and SwiftStats and SwiftProjectLint under `~/xcode_projects/`. Files are cited inline and in §12.7.

---

## Appendix A: SwiftLint parity probes

These three probes back the SwiftLint rules in §4.3 and the worked check in §4.2. They were run against SwiftLint 0.65.1 with `only_rules: [cyclomatic_complexity]` and `warning: 0`. Both tools read syntax only, so free names such as `a` and `it` need not resolve. In the library they become test fixtures at `Tests/SwiftCodeMetricsTests/Fixtures/` (`SwiftLintProbe1.swift`, `SwiftLintProbe2.swift` and `DecisionCountCheck.swift`), and the v0.1 SwiftLint parity test runs on them (§16).

### A.1 Probe 1

It shows that local-type getters, subscripts and `deinit`, and local computed variables and `didSet` observers, fold into the enclosing `func`; that a local type's `func` and `init` are skipped; that closures fold in; that `switch n {}` scores 0; and that operators, `where`, `for case`, extra condition elements and `??` add nothing (§4.3).

```swift
func outer(_ xs: [Int]) -> Int {
    struct Local {
        var v: Int { if a { return 1 } else { return 2 } }
        subscript(i: Int) -> Int { if i > 0 { return 1 }; return 0 }
        deinit { if b { print(1) } }
        func m() { if c { print(2) } }
        init() { if d { print(3) } }
    }
    var local: Int { if e { return 1 }; return 0 }
    var obs = 0 { didSet { if f { print(4) } } }
    xs.forEach { if $0 > 0 { print($0) } }
    return 0
}
struct S {
    var g: Int { if a { return 1 }; return 0 }
    var h: Int { get { if a { return 1 }; return 0 } set { if b { } } }
    deinit { if a { } }
    subscript(i: Int) -> Int { if a { return 1 }; return 0 }
}
func q(_ xs: [Int?]) {
    for case let x? in xs where x > 0 && x < 9 { print(x) }
    if a && b || c, d { }
    let z = a ?? b
    while let y = it.next(), y > 0 { }
}
func noCases(_ n: Never) { switch n {} }
```

### A.2 Probe 2

It shows that a local type's stored-property initial value and its member-list `#if` members fold in (`a1`), that `for case` adds nothing (`a2`), that switch cases in every `#if` clause are summed (`a3`: four cases across two clauses gave 4), and that a default-argument closure counts in neither function (`a4`) (§4.3).

```swift
func a1() -> Int {
    struct L {
        var x: Int = { if c { return 1 }; return 2 }()
        #if DEBUG
        var y: Int { if d { return 1 }; return 0 }
        #endif
    }
    return 0
}
func a2(_ pairs: [(Int, Int)]) {
    for case let (p, q) in pairs { print(p, q) }
}
func a3(_ n: Int) -> Int {
    switch n {
    #if DEBUG
    case 1: return 1
    case 2: return 2
    #else
    case 3: return 3
    #endif
    default: return 0
    }
}
func a4(_ n: Int) -> Int {
    func inner(_ k: Int = { if z { return 1 }; return 2 }()) -> Int { k }
    return inner()
}
```

### A.3 Probe 3: the §4.2 worked check

D = 8 and SL = 5 (§4.2).

```swift
func probe(_ c: Int) -> Int {
    guard let a = Optional(c), c > 1 else { return 0 }
    for x in [1, 2] where x > 0 { print(x) }
    switch c {
    case 1, 2: return 1
    case 3 where a > 2: return 2
    default: break
    }
    return c > 0 ? 1 : 2
}
```

---

## Appendix B: changes from the drafts

### Changes in Part A since the first complexity draft

- Renamed SwiftComplexity to SwiftCodeMetrics. "Unit" is now "function" throughout.
- Row 16: `guard` is a fundamental +1; its `else` body still nests.
- Row 17 and §3.5.2: a condition list of two or more elements costs +1 once; each expression element is its own root; no synthetic `&&`.
- Row 50 and §3.5.2: parentheses (nested or not) and `try`, `await`, `unsafe`, `consume`, `copy` and `borrow` operands are transparent for splicing, in condition elements too.
- §3.5.1: folding reworded; folded-mode rules for hoisted `try`/`await`/`unsafe`. §3.5.3: D counts real operator tokens only, `??` included. §3.5.4: precedence corrected, segments at `=` and `->`, ternaries in conditions allowed, folded nesting by tree.
- §3.3: flat `else if` chains, guard `else` is not hybrid, `#if` placement, member-list and attribute `#if` not scored, body-container citations.
- §3.4: `Self.` only in static functions, shadowing, trailing closures and variadics, operator functions, overload false positives, zero-amount `possibleRecursion`.
- §2.1: local computed and observed variables, local-type property initialisers, default arguments.
- §4.2: max(0, arms − 1); the `#if` clause-choice rule for arms; irrefutable `for case` excluded; `decisionCountIgnoresTrivialSwitches`.
- §4.3 and §4.4: the parent's SL folds local bodies; the full list of conditions for the switch formula.
- §5 and §14.2: `.opaqueResult` hint for `some View` and other builder protocols; `decisionCount` threshold justified by NIST and compared as `mccabe`.
- §13: Codable types with UTF-8 offsets; `FunctionKind`, `ComplexityScores`; `closureNesting`; defined `maxNesting`; shared rule cases.
- Citation fixes: Kotlin commit, `SyntaxCollections.swift` path, `then` and `do` gates, Sonar Java lines, SwiftLint SourceKit-era evidence.
- Examples: 6.8 C 6 → 4. New 6.17 (nested guard chain) and 6.18 (condition-list order). All other C, D and SL values are unchanged. (6.16's side remark on Sonar's folded score was later corrected from 4 to 3; see the last subsection.)

### Changes made when merging the two parts

- One set of definitions (§2) replaces the complexity draft's §1.3 and the coupling draft's §1.4. Both parts refer to it.
- The coupling draft said the library reads source with `SwiftParser`; the complexity draft said consumers parse and the library links only `SwiftSyntax`. Now consumers parse, and the library links `SwiftSyntax` and, from v0.2, `SwiftLexicalLookup` (§1.3, §13).
- One API (§13) replaces both sketches. `FunctionComplexity` and `FunctionResult` are one `FunctionRecord`, with both the index link and the PRD key. Positions use `ByteRange` plus a `LineRange`, not `SourceRange`. `complexityDefinitionVersion` and `definitionVersion` are fields of one `MetricsVersion`. `MetricsOptions` is `Codable` and holds `ComplexityOptions`; the platform table became a parameter.
- `.propertyInitializer` records: the coupling draft gave initial values to the type, the complexity draft made them functions. Both now hold: the record carries complexity only, has no function-level coupling, and is not a WMC term (§2.1).
- Local computed and observed variables are treated like nested functions by Part B, as Part A already did. WMC counts them as their own terms (§9.2).
- Calls in freestanding macro arguments count towards fan-out, matching Part A's rule that arguments are analysed as written (§2.7).
- Parameter counts of a subscript go on one record (§8.3).
- Part B's worked examples now state WMC values, since `guard` is decided (§12.1, §12.5).
- Part B's literature citations use labels (§17). `SS/` paths are now `N/`. "The specification" in Part A now reads "Sonar's specification".
- Open questions are one list (§15). The two `#if` questions, the two macro questions and the versioning question are merged. Q1 (key ownership) and Q33 (PRD D3) are new.

### Changes made after verification

Two independent checks of the merged text led to these changes. No worked-example number changed except the two noted.

- §12.7 `MarkedCircularBuffer`: Ce 1 → 2 (`CircularBuffer` and `CircularBuffer.Index`), `ceFamily` 1. 6.16: the remark on Sonar's folded score now says 3 (4 if `guard` were an `if`).
- Part A: node-level irrefutable `for case` test (§4.2); `guard` exception in §3.1; complete anchors, `elseIf` for SL, no zero-amount `switchArms` (§13.3); folded-input roots, ternaries and casts (§3.5.1); parameter shadowing, own-body scope, operator-function wording and `possibleRecursion` scope (§3.4); `fallthrough` wording (rows 25–26, §4.2, §4.4); D's operator scan follows the `#if` rule (§3.5.3); all 17 accessor specifiers (§2.1); every `func` and `init` is a record, globals and statics get `.propertyInitializer`, `.topLevelCode` only with statements, one record order (§2.1, §13.1); trivial-switch and attribute-`#if` wording; column renamed in §3.5.2; `closureNesting` excludes `defer`; the labelled-jump rule case spelled `labeledJump`; probes moved into Appendix A.
- Part B: leading underscores skipped in type-name candidates (§7.3); bare statics of the innermost type (§7.2, §7.5); public memberwise initialisers, `ExtensionFact`, `ConformanceFact`, `declarationTypeReferences` and name lists on `TypeResult`, `StoredLookupResult` (§13.5); dependency claims (§1.3, §13); §10.2 heading names its real metrics; `byReceiver` and the default diagnostic list (§8.1); extension merging moved to v0.2 (§16); `constraint` edge kind and the `isWeakOrUnowned` rule (§9.4); `typeCycles` versus `circularDependency` (§10.3, §14.4); `conformerCount` from conformances (§9.5); unproduced provenance case dropped and `moduleEdges` defined (§10.1); `ServerSocketChannel` wording; "would stay 2" (§12.6); exact greps (§7.4); nested-function calls excluded from fan-out (§8.1).
- SE-0380 link corrected to `0380-if-switch-expressions.md`.

### Changes made during the v0.1 implementation

- `ResultBuilderHint` has no `.none` case; `ComplexityScores.resultBuilderHint` is optional, nil for no hint (§13.2). Why: SwiftLint's `discouraged_none_name`, since `.none` is easily read as `Optional.none`.
- Camel-cased enum cases encode as snake_case strings (`computed_getter`, `labeled_jump`, `swift_lint`); single-word cases encode as their names. Swift code uses the case names as written in §13. Why: SwiftLint's `raw_value_for_camel_cased_codable_enum` and `redundant_string_enum_value` together require raw values that differ from the case name, and SwiftStats stores these values.
- v0.1's `FunctionRecord` has the §13.2 fields up to `couplingStatus`; `parameters`, `fanOut`, `commonCoupling` and `typeReferences` arrive with v0.2. `MetricsOptions` holds `complexity` only until v0.2 and v0.3 add their options.
- Readable names: a subscript's implicit getter is `subscript(_:).get`, a property's initial value `name.initializer`, and top-level code `<top-level code>`.

### Changes made during the v0.2 implementation

- **Platform table (§7.4).** The generator also harvests the types that top-level extensions in the interfaces extend. Without this, `DispatchQueue` and `XCTestCase`, which come from C and Objective-C headers, were missing.
- **`ModuleAnalysis` in v0.2** has `module`, `isTest`, `functions`, `imports`, `version` and `options`. `types`, `typeEdges`, `typeCycles` and `unresolvedExtensions` arrive with v0.3. `RawReferences` and `DeclarationFacts` are public but opaque: callers store and pass them, and only the library reads them.
- **Raw type references.** After the file pass, `typeReferences` holds the written type names only, with `bucket` nil. Uppercase names in expression position need the module pass to tell a type from a free function or a global, so they appear only after it. After the module pass, `module` and `platform` references are `exact`, `external` ones `approximate`, and `unresolved` and `ambiguous` ones have no bucket.
- **Call keys (§7.5).** `Outer.Inner(...)`, an uppercase member called on a type, constructs the nested type and is keyed `Outer.Inner.init(...)`. That includes nested names syntax cannot find, such as a macro-generated `State`. A call of a global closure variable gets receiver `implicit` and also counts in `globalRefs`. An uppercase unknown name in a file that does not import XCTest is an external type, so there `XCTAssertEqual(a, b)` is keyed `XCTAssertEqual.init(_:_:)`, as §7.3's order implies.
- **`distinctBaseNames`** counts the base names of the keys `fanOut` counts.
- **Capture lists (§7.2).** `[x]` declares a local and reads nothing. `[y = x]` reads `x` like any other name.
- **Decisions from four review rounds** (each with a regression test):
  - `#if` in a body: conditions are never walked, so `#if os(macOS)` is not a call. A name declared earlier in any enclosing clause is a local: lexical lookup with no build configuration reads only `#else` clauses, and every clause is walked (§2.6). A clause at file scope is not a body: its declarations stay globals, free functions and types. `guard case let .some(x)` and tuple bindings declare locals too.
  - `#if` variants: a typealias whose variants reach different types is ambiguous, with no edge (§7.3), and a closure alias whose variants differ in shape is not a closure parameter. A global or static that is `let` in one clause and `var` in another is mutable, whatever the clause order (§2.6's union).
  - Key-path components (`\.name`) and attribute names (`@escaping`) are not value or type references.
  - Local types: a type declared in an unscored initial value's closure, or in a freestanding macro that no record encloses (`#Preview { ... }`), is local to that context, so it never merges with a module type of the same name. Records inside such a macro are keyed under it (`#Preview @ file / ...`). A local type's chain includes its enclosing local types and the types around its owning function, and function-local types are found before those outer types.
  - Extensions of a type the module does not declare form extension groups: their members and typealiases resolve for code inside the extension (`self.doubled()`, `String.blank()`), and types nested in them keep their written path (`String.Limits`). A group is never a type-reference target, and `Self` inside it is the platform or external type: `Self.X` finds the group's own nested types and typealiases first, and in an extension of a module typealias to a platform type (`extension Celsius` where `Celsius = Double`), `Self` is the alias target. An extension of a missing nested type of a module type (`extension Feature.State`) forms no group.
  - Typealiases: file-private ones are visible only in their file; expansion uses the alias's own position, its own generic parameters and those of every type around it. Closure parameters expand through the §7.3 order, including qualified (`Network.Handler`), optional (`Callback?`) and extension-group aliases. `any P` and `some P` targets name `P`.
  - Type names: backticks are not part of a name, so `` enum `Type` `` resolves from `` `Type`.word ``. `Self.State` naming an associated type is not coupling, like bare `State`. A placeholder `_` (SE-0315) is no reference. `Lib.Global` names a module global, not a type.
  - Call keys: a bare enum-case call is keyed on its enum (`Token.number(_:)`). `M.f(...)` and `M::f(...)` classify `f` as an unqualified callee of `M`, so `Swift.print` is still excluded and `Foundation.NSLog` is `free`. `Swift.Int(x)`, `Self.Inner(...)` and `Self.Inner.init(...)` are `.init` keys on the resolved or spelled type. A static property on a platform type is a `?` receiver (`FileManager.default.x()`). A `Module::` selector cannot be shadowed by a type named like the module, but a dotted name can: with `enum Lib` in module `Lib`, `Lib.analyze()` is `Lib.analyze()` (receiver `T`), `Lib.Options()` is `Lib.Options.init()`, and `Lib.version` is a static. `Lib.X()` and `Lib::X()` name the top-level `X`, never a nested type of the current one. `T()`, `T.init()` and `T.make()` on a generic parameter are `T` keys on the spelled name (`T.init()`).
  - Common coupling: `staticRefs` counts properties only, never unapplied static methods; a property wins over a static method of the same base name. A bare call of a static closure property counts, unless a static method with the same labels exists. `Self.Cache.shared`, `Lib::counter`, `Lib.onEvent()` and backticked names (`` static let `default` ``) resolve as written. Singletons may be initialised through a qualified name (`Services.Cache()`, `Lib.Manager()`). A baseless `.init()` makes one only with no type annotation or one naming the type itself: `static let decoder: JSONDecoder = .init()` is not a singleton of its enclosing class.
  - Free functions are visible across files unless `private` or `fileprivate`.
  - A typed `throws(E)` type is a `signature` reference, for functions, initialisers and accessors.
  - Part A (fourth round): recursion matching ignores backticks on names and labels (`` func `default`(depth:) `` calling `Self.default(depth:)`). `<top-level code>`'s SL count skips types and extensions inside a top-level `#if` that also holds statements, and its `hasSyntaxErrors` covers every item in its range, declarations between the statements included (§2.8).
- **Speed (§16).** The 2 s target is checked in an optimised build: a release build took 1.0 s over swift-collections' 576 files with sequential file passes. `analyzeModule(_:)` now runs the file passes in parallel. The test suite enforces 2 s in release builds and a loose bound in debug builds.

### Changes made during the v0.3 implementation

- **Names of three or more characters.** SwiftLint's `identifier_name` rule rejects `from`, `to`, `ce` and `ca`, so the API spells them `TypeCoupling.source`/`target`, `ModuleDependency.source`/`target`, `TypeCouplingSummary.ceTotal` and `ModuleCoupling.caDirect`. The metrics keep their names in the text. `CohesionOptions.inheritedAttributesFromModuleSuperclasses` is `inheritsModuleSuperclassAttributes`, under the 40-character limit.
- **`A.B` in an expression (§7.3 step 4).** An expression candidate followed by uppercase member names (`SyncUpForm.State(...)`) targets the longest prefix that names a module type, here the nested `SyncUpForm.State`, as §12.7 counts it. This also changes function `typeReferences`, so `couplingDefinition` is `coupling-2`.
- **Members.** A member is identified by its key without `#if` conditions, numbering or accessor, so accessors of one property or subscript form one member and `#if` variants merge (§2.6). NOM and the cohesion nodes come from the function records a type owns; a nested function belongs to the member around it. A protocol's NOM comes from its requirements, `#if` variants merged.
- **Shapes not spelled out in §13.5.** `TypeSizes` holds the §9.1 counts and `storedProperties`; `WMC` has `cognitive`, `decisions` and `isDefaults` (true for `wmcDefaults`); `CohesionComponent` has `members`, `attributes`, `extensions` and `includesPrimaryDeclaration`; `ExclusionReason` has one case per row of the §9.3 table plus `observer`; `TypeCouplingSummary` counts distinct names, with `internalRefs` the number of distinct family types named; `ModuleCoupling` holds counts only.
- **Not-applicable kinds.** For an enum, protocol or extension group, the cohesion graph is not built: `components`, `isolatedMembers`, `excludedMembers` and the reference lists are empty and `nodeCount` is 0.
- **Edge kinds.** An inheritance-clause name becomes `refinement` (protocol to protocol), `conformance` (other type to protocol) or `inheritance` (any other target). Generic arguments inside an inheritance clause get the same kind as the entry they appear in. Every stored property's annotation and initial value counts, static ones included; only instance properties are attributes.
- **Custom attributes** are the attribute names written with an uppercase first letter. `hasKnownAttachedMacro` matches the last dotted component of a name, generic arguments stripped.
- **Order.** `types` follows the first declaration of each type: file order, then offset. `typeEdges` follows `types`, each type's edges sorted by target. Each `typeCycles` component is sorted, and the components by their first type.
- **Corpus report.** It takes about half a minute in a debug build, so it runs only when `SCM_CORPUS_REPORT` is set. Its figures are recorded under Q28 and Q31. The §16 speed test keeps its 2 s bound in release builds; its debug bound is 30 s, because the corpus suites run beside it.
- **Decisions from the first v0.3 review round** (each with a regression test):
  - Members: a private member's key carries its file, so same-text private members in two files are two members, and WMC adds them. A function inside a stored property's initial value is a WMC term but not a member or a cohesion node. Protocol requirements that differ in labels or types are separate; a default matches a requirement by base name and labels, initialisers and subscripts included. Enum cases count by name and labels (`move(x:)`, `move(dx:)`). Attributes inside a `#if` in an attribute list are read. `extension Swift.String` joins the `String` group.
  - Cohesion: calling a stored closure property touches it. A read of a stored property is a touch, never an edge to a method with the same base name, and a call with no label match on a name that is a stored property is the closure, not those methods. Rule 4 applies to `self.$a` and `self._a`.
  - Coupling: a protocol's requirement signatures (parameter, result, `throws` and property types) are `signature` references in `declarationTypeReferences`; a requirement's or a generic typealias's own generic parameters are not references. `A.B` in an expression reaches nested types under a platform type (`String.Limits`), after a module qualifier (`Lib.Form.State()`, `Lib::Form.State()`), after `Self` (`Self.State()`), and through a specialisation (`Box<Int>.Item()`); `A.B` also finds nested types of A's in-module superclasses. Generic arguments in an inheritance entry take the kind its first name gives.
  - Conformances: a typealias composition in an inheritance clause expands into its protocols, for conformances, conformerCount and `conformance` or `refinement` edges, and is never a possible superclass. An extension with bound generic arguments (`extension Box<Int>: P`) is constrained, so its conformances are conditional. Unresolved extensions resolve their conformances' targets and flag them the same way.
  - Module level: an import's module name is read without backticks.
- **Decisions from the second v0.3 review round** (each with a regression test):
  - Extension groups are keyed by the type the extended name resolves to, with any module qualifier stripped and module typealiases, member ones included, expanded: `extension Swift.String`, `extension String` and `extension Text` where `Text = String` form one group, as do `extension SwiftUI.View` and `extension View`. A group never takes a module type's key: in a module that declares `Result`, `extension Swift.Result` keeps its written path. Types nested in a group sit under its key (`String.Limits`). `extension User.ID` where `ID = UUID` is a group, not an unresolved extension.
  - Members: computed property requirements that differ in type across `#if` clauses are two; an operator default matches its requirement by arity, since operators have no argument labels. A context's file (a private subscript with explicit accessors) is part of the member's identity. A function in an initial value is not a member even when its signature uses a module selector. In `var a, b: Int` both facts get `Int`. A freestanding macro in a member block (`#warning`) is not an instance member, so the enum around it can still be a namespace.
  - Cohesion: `T.self` and `\.self` are not whole-`self` uses. A `_name` declared as such, own or inherited, is not a wrapper name. A call is a touch of a stored closure property only when no method with those labels exists. A compound reference (`self.f(y:)` or `f(y:)`) joins the one overload its labels name. A computed property read joins the property node, not methods with the same base name.
  - Coupling: a subscript requirement's own generic constraints and `where` clause, and the typed `throws` of property and subscript requirement accessors, are `signature` references. Generic arguments of a platform protocol entry (`protocol Store: Collection<Item>`) take its kind: `refinement` in a protocol, `conformance` elsewhere. A property wrapper inside a `#if` in the attribute list gives a `wrapper` edge.
  - Conformances: typealias compositions expand recursively, through nested compositions and alias chains; a module class in a composition is the class's superclass, with an `inheritance` edge, and is not a conformance. An extension of a typealias to a bound generic type (`IntBox = Box<Int>`) is constrained.
  - Module level: `@_exported` inside a `#if` in an import's attribute list is read.
- **Decisions from the third v0.3 review round** (each with a regression test):
  - Extension groups: a module type nested in a group is found by every spelling of the group's type: through a module typealias (`Celsius.Scale` where `Celsius = Double`), a module qualifier (`Swift.String.Limits`) or a selector. Its extensions merge into it, and references resolve to it, in type and expression position. The collision guard applies only when the resolved path names an unrelated module type. `extension Swift::Result` keys like `extension Swift.Result`. Inside a group kept on its written path, `Self` is the platform or external type that path names. A group's records are found by resolving the record's written path from its own file, so a file-private `typealias Num` that means `Double` in one file and `Int` in another sends each file's records to its own group. Types nested in groups register shortest prefix first, so `extension Celsius.Unit { struct Deep }` sits under `Double.Unit`.
  - Superclasses: a direct composition in a class's inheritance clause (`class Card: Base & Themed`) names `Base` as the superclass, as the alias form does. Superclass chains are recomputed as the table grows, so a superclass declared in an extension later in the file is found whatever the file order.
  - Conformances: an extension of a typealias that reaches a bound generic type along an alias chain (`Counts = IntBox`, `IntBox = Box<Int>`) is constrained. A pass-through generic typealias (`Handler<T> = Box<T>`, `List<T> = [T]`) binds nothing, so its extensions are not. A composition that reaches one alias twice (a diamond) expands it twice, with no alias left as a conformance. `#if` variants of a composition typealias with different members conflict, so the name is ambiguous.
  - Coupling: a protocol's class constraint (`protocol Themed: BaseView`, or a module class inside a composition alias) is an `inheritance` edge, not `refinement`. The generic arguments of an unknown protocol in a class's later inheritance entry, or in an extension's, take `conformance`, since only a class's first entry can be a superclass. A typealias composition in any other position (a stored property, a signature, a constraint) names each of its members with that position's kind, in `declarationTypeReferences` and in function records' `typeReferences`, as if the composition were written (part of `coupling-2`). The compiler's uppercase attributes (`@IBOutlet`, `@IBInspectable`, `@IBAction`, `@NSManaged`, `@NSCopying` and the like) give no `wrapper` reference. `platformNameCount` counts `Swift.Int` and `Int` as one name.
  - Cohesion: rule 4 retries a bare `_a` as `a` only when nothing declares `_a`. A `_a` that resolves to a global, free function, static or lexical binding is recorded as written.
- **Decisions from the fourth v0.3 review round** (each with a regression test):
  - Extensions: once the table is complete, every merged extension is resolved again and moved if its type changed. So `extension Outer.Config` lands on `Settings` when a later `extension Outer { typealias Config = Settings }` hides an inherited `Base.Config`, whatever the source order. Types nested in groups register one level at a time: one whose prefix stops resolving in a half-built table waits for the next round. A group's records are found by the same key its extension registers under, collision guard included, so `extension Swift.Result` next to a file-private `Result` keeps its own records. The module's own selector drops from an extension path (`extension Shop::Item` in Shop is `Item`, even when Shop declares a type named `Shop`), and `extension Swift::Result` resolves its inheritance and `where` clauses from the group, like `extension Swift.Result`.
  - Member typealiases: a private member typealias is visible only in its own file, so private aliases with one name in two files neither shadow nor conflict.
  - Inheritance clauses: a type's inheritance clause resolves outside its body. Its generic parameters are visible but its nested types are not, so `class Outer: Base` with a nested `Outer.Base` inherits, couples to and conforms through the top-level names, as `superclass` already did.
  - Members: an attribute named after a macro the module declares sets `hasKnownAttachedMacro` whatever its case (`@registerAll`). A member variable's attribute arguments are a key context like an initial value (`var volume: Int <attributes>`), so a function in `@Clamped({ ... })` is not a member.
  - Cohesion: only instance methods compete with a stored closure property for a call, so a static `fetch()` does not stop `self.fetch()` touching `fetch`. A use whose name the type declares only as methods, none matching a call's labels, reaches a superclass's property of that name: a touch or an inherited reference, not an edge to the own methods. Reading an own computed property that is excluded (`description`) joins nothing. An uppercase stored property used as a member-access base (`ID.lowercased()`) is a touch. `super.f(y:)` is listed by its base name, and an undeclared `super.$a` or `super._a` is `a`.
  - Coupling: a composition typealias written with `any` (`typealias Deps = any HasAPI & HasStore`) expands like the bare form. In an inheritance clause, a composition alias's platform, external and unresolved members are counted and listed as if written, with `conformance` (`refinement` in a protocol). Type names in a member-level freestanding macro's arguments are `body` references (§2.7). `TypeReference.resolvedName` carries the platform or external type a reference names, and `platformNameCount` and `externalNameCount` count those, so `Self` in `extension String`, `String`, `Swift.String`, `XCTest.XCTestCase` beside `XCTestCase`, a member `typealias ID = UUID` beside `UUID`, and `Lib.Widget` beside `Widget` are each one name.

