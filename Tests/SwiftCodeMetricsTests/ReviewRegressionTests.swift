//
//  ReviewRegressionTests.swift
//  SwiftCodeMetricsTests
//
//  Regression tests from the v0.2 review: each case was a confirmed
//  disagreement with the spec, reduced to a reproducer.
//

import SwiftCodeMetrics
import Testing

@Suite("v0.2 review regressions")
struct ReviewRegressionTests {
    @Test("key-path components are members of the root, not globals or statics (§7.2)")
    func keyPathComponents() {
        let record = record("titles(of:)", """
        let title = "Library"
        struct Book { var title: String }
        func titles(of books: [Book]) -> [String] { books.map(\\.title) }
        """)

        #expect(record?.commonCoupling?.globals.isEmpty == true)
    }

    @Test("a local type in an implicit getter resolves its own statics (§7.2)")
    func localTypeInGetter() {
        let record = record("render(_:)", """
        struct Report {
            static let prefix = "Report"
            var summary: String {
                struct Formatter {
                    static let prefix = "Total: "
                    func render(_ value: Int) -> String { prefix + String(value) }
                }
                return Formatter().render(3)
            }
        }
        """)

        #expect(record?.commonCoupling?.statics == ["Formatter.prefix"])
    }

    @Test("a type nested in an extension of String is a module type (§2.2)")
    func nestedInPlatformExtension() {
        let record = record("clamp(_:)", """
        extension String {
            enum Limits {
                static let maxLength = 40
                static func clamp(_ count: Int) -> Int { Swift.min(count, maxLength) }
            }
        }
        """)

        #expect(record?.commonCoupling?.statics == ["String.Limits.maxLength"])
        #expect(Modules.headline(record) == ["free.min(_:_:)"])
    }

    @Test("bare calls of enum cases are keyed on the enum (§7.5)")
    func enumCaseCalls() {
        let record = record("parse(_:)", """
        enum Token {
            case number(Int)
            case word(String)
            static func parse(_ text: String) -> Token {
                if let value = Int(text) { return number(value) }
                return word(text)
            }
        }
        """)

        #expect(Modules.headline(record) == ["Int.init(_:)", "Token.number(_:)", "Token.word(_:)"])
        #expect(record?.commonCoupling?.statics.isEmpty == true)
    }

    @Test("a local type in an unscored initial value's closure resolves its own statics")
    func localTypeInInitialValue() {
        let record = record("doubled()", """
        struct Config {
            let scale: Int = {
                struct Helper {
                    static let base = 2
                    func doubled() -> Int { base * 2 }
                }
                return Helper().doubled()
            }()
        }
        """)

        #expect(record?.commonCoupling?.statics == ["Helper.base"])
    }

    @Test("nested functions keep the enclosing type: nested types, generics and Self statics (§7.3)")
    func nestedFunctionContext() {
        let analysis = Modules.analysis("Lib", [
            ("A.swift", """
        struct Outer<T> {
            struct Item {}
            static var count = 0
            func make() {
                func helper(_ item: Item, _ value: T) { _ = Self.count }
                helper(Item(), make2())
            }
            func make2() -> T { fatalError() }
        }
        """)
        ])
        let helper = Modules.record("helper(_:_:)", in: analysis)

        #expect(helper?.typeReferences.map(\.target) == [TypeKey(module: "Lib", path: ["Outer", "Item"])])
        #expect(helper?.commonCoupling?.statics == ["Outer.count"])
    }

    @Test("explicit subscript accessors keep the enclosing type")
    func subscriptAccessorContext() {
        let record = record("subscript(_:).get", """
        struct Grid<Cell> {
            static var origin = 0
            subscript(index: Int) -> Cell {
                get { _ = Self.origin; fatalError() }
                set { }
            }
        }
        """)

        #expect(record?.commonCoupling?.statics == ["Grid.origin"])
        #expect(record?.typeReferences.map(\.spelling) == ["Int"])
    }

    @Test("attribute names are not type references")
    func attributeNames() {
        let record = record("run(_:)", "func run(_ work: @escaping () -> Void) { work() }")

        #expect(record?.typeReferences.map(\.spelling) == ["Void"])
    }

    @Test("a private typealias in another file is not visible (§7.3)")
    func privateTypealias() {
        let analysis = Modules.analysis("Lib", [
            ("A.swift", "struct Apple {}\nprivate typealias Fruit = Apple"),
            ("B.swift", "struct Banana {}\nprivate typealias Fruit = Banana\nfunc eat(_ fruit: Fruit) {}")
        ])

        let eat = Modules.record("eat(_:)", in: analysis)
        #expect(eat?.typeReferences.first?.target == TypeKey(module: "Lib", path: ["Banana"]))
    }

    @Test("a Module:: selector on an expression name resolves through that module")
    func moduleSelectorExpression() {
        let record = record("stamp()", "import Foundation\nstruct Date {}\nfunc stamp() -> Any { Foundation::Date() }")

        #expect(record?.typeReferences.filter { $0.spelling == "Date" }.map(\.bucket) == [.platform])
        #expect(Modules.headline(record) == ["Date.init()"])
    }

    @Test("a typealias to an outer generic parameter is not coupling")
    func aliasToOuterGeneric() {
        let record = record("read(_:)", """
        struct Outer<Payload> {
            struct Inner {
                typealias Value = Payload
                func read(_ value: Value) {}
            }
        }
        """)

        #expect(record?.typeReferences.isEmpty == true)
    }

    @Test("a static property of a platform type is a `?` receiver (§7.5)")
    func platformStaticReceiver() {
        let analysis = Modules.analysis("Lib", [
            ("A.swift", """
        import Foundation
        struct Store {
            func exists(at path: String) -> Bool { FileManager.default.fileExists(atPath: path) }
            func later() { DispatchQueue.main.async { } }
        }
        """)
        ])

        #expect(Modules.keys(Modules.record("exists(at:)", in: analysis), .unknown) == ["?.fileExists(atPath:)"])
        #expect(Modules.keys(Modules.record("later()", in: analysis), .unknown) == ["?.async(_:)"])
    }

    @Test("module-qualified callees: types are .init, functions are classified as unqualified (§7.5 step 2)")
    func moduleQualifiedCallees() {
        let analysis = Modules.analysis("Lib", [
            ("A.swift", """
        import Foundation
        import MyKit
        func convert(_ value: Double) -> Int { _ = Foundation.Date(); return Swift.Int(value) }
        func check(_ ok: Bool) { Swift.print("checking"); Swift.precondition(ok); MyKit.configure() }
        """)
        ])
        let convert = Modules.record("convert(_:)", in: analysis)

        #expect(Modules.headline(convert) == ["Date.init()", "Int.init(_:)"])
        #expect(convert?.fanOut?.distinctBaseNames == 1)
        #expect(Modules.headline(Modules.record("check(_:)", in: analysis)) == ["implicit.configure()"])
    }

    @Test("a Swift:: selector skips lookup, so a shadowed name is the free function")
    func moduleSelectorCall() {
        let record = record("max.get", """
        struct Heap {
            var buffer: [Int] = []
            var max: Int? { Swift::max(buffer[1], buffer[2]) }
        }
        """)

        #expect(Modules.headline(record) == ["free.max(_:_:)"])
    }

    @Test("Self.Inner(...) constructs the nested type")
    func selfNestedInit() {
        let record = record("make()", """
        struct Outer {
            struct Inner { init(_ value: Int) {} }
            func make() -> Inner { Self.Inner(1) }
        }
        """)

        #expect(Modules.headline(record) == ["Outer.Inner.init(_:)"])
    }

    @Test("closure typealiases: optional, qualified and shadowed (§8.3)")
    func closureTypealiases() {
        let analysis = Modules.analysis("Lib", [
            ("A.swift", """
        typealias Completion = (() -> Void)?
        typealias Callback = () -> Void
        typealias MaybeCallback = Callback?
        typealias Handler = () -> Void
        enum Network { typealias Handler = (Int) -> Void }
        func load(completion: Completion) {}
        func save(callback: MaybeCallback) {}
        struct Client {
            func fetch(onDone: @escaping Network.Handler) {}
            func peek(with handler: Network.Handler) {}
        }
        struct Service {
            struct Handler { var name: String }
            func register(_ handler: Handler) {}
        }
        """)
        ])
        func counts(_ name: String) -> [Int] {
            let parameters = Modules.record(name, in: analysis)?.parameters
            return [parameters?.closureParameterCount ?? -1, parameters?.escapingClosureParameterCount ?? -1]
        }

        #expect(counts("load(completion:)") == [1, 1])
        #expect(counts("save(callback:)") == [1, 1])
        #expect(counts("fetch(onDone:)") == [1, 1])
        #expect(counts("peek(with:)") == [1, 0])
        #expect(counts("register(_:)") == [0, 0])
    }

    @Test("unapplied static methods are not static property references (§8.2)")
    func staticMethodReferences() {
        let analysis = Modules.analysis("Lib", [
            ("A.swift", """
        enum Parser {
            static func parse(_ text: String) -> Int? { Int(text) }
            static func parseAll(_ items: [String]) -> [Int] { items.compactMap(parse) }
        }
        func convert(_ items: [String]) -> [Int] { items.compactMap(Parser.parse) }
        """)
        ])

        #expect(Modules.record("convert(_:)", in: analysis)?.commonCoupling?.statics.isEmpty == true)
        #expect(Modules.record("parseAll(_:)", in: analysis)?.commonCoupling?.statics.isEmpty == true)
    }

    @Test("a nested class initialised by its qualified name is a singleton")
    func qualifiedSingleton() {
        let record = record("warm()", """
        enum Services { final class Cache { static let shared = Services.Cache() } }
        func warm() { _ = Services.Cache.shared }
        """)

        #expect(record?.commonCoupling?.singletons == ["Services.Cache.shared"])
    }

    @Test("declarations inside a top-level #if are not top-level code")
    func topLevelIfConfigDeclarations() {
        let analysis = Modules.analysis("App", [
            ("main.swift", "#if DEBUG\ntypealias Clock = DebugClock\nprint(\"debug build\")\n#endif"),
            ("DebugClock.swift", "struct DebugClock {}")
        ])

        #expect(Modules.record("<top-level code>", in: analysis)?.typeReferences.isEmpty == true)
    }

    private func record(_ name: String, _ source: String) -> FunctionRecord? {
        Modules.record(name, in: Modules.analysis("Lib", [("A.swift", source)]))
    }
}
