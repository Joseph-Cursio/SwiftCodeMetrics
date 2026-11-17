//
//  ResolverTests.swift
//  SwiftCodeMetricsTests
//
//  Spec Q25 and §7.2: the resolver's handling of shadowing, shorthand
//  bindings, closure parameters, capture lists, extensions' generic
//  parameters, parameterless closures and names with no identifier, plus
//  the four real cases §7.2 cites.
//

import Foundation
import SwiftCodeMetrics
import Testing

@Suite("Name resolution (Spec §7.2, Q25)")
struct ResolverTests {
    private static let source: [(path: String, source: String)] = [
        ("S.swift", """
        struct S {
            static var total = 0
            static var limit: Int?
            var count = 0
            func shadowed(total: Int) -> Int { total }
            func shorthand() { if let limit { print(limit) } }
            func closureParameter() { _ = [1].map { total in total } }
            func captureList() { _ = { [current = total] in current } }
            func parameterless() { run { count } }
            func dollar() { _ = [1].map { $0 } }
            func usesSelf() { _ = self.count; _ = Self.total }
        }
        struct Box<T> { var value: T }
        extension Box { func get() -> T { value } }
        """)
    ]

    private static let home = FileManager.default.homeDirectoryForCurrentUser.path

    @Test("a parameter shadows a static")
    func shadowing() {
        #expect(names("shadowed(total:)") == ["total local"])
    }

    @Test("a shorthand binding's later uses are locals")
    func shorthandBinding() {
        #expect(names("shorthand()") == ["limit local"])
    }

    @Test("closure parameters are locals")
    func closureParameters() {
        #expect(names("closureParameter()") == ["total local"])
    }

    @Test("a capture initialiser reads the static; the closure body uses the capture")
    func captureList() {
        #expect(names("captureList()") == ["total static S", "current local"])
    }

    @Test("a parameterless closure still reaches members past .lookForImplicitClosureParameters")
    func parameterlessClosure() {
        #expect(names("parameterless()") == ["count own"])
    }

    @Test("$0 is never looked up")
    func dollarNames() {
        #expect(names("dollar()").isEmpty)
    }

    @Test("an extension reaches members past .lookForGenericParameters, and T is a generic parameter")
    func extensionGenericParameters() {
        #expect(names("get()") == ["value own"])
        let record = Modules.record("get()", in: Modules.analysis("Lib", Self.source))
        #expect(record?.typeReferences.isEmpty == true)
    }

    @Test("self and Self are not looked up; Self.total is a static")
    func noIdentifier() {
        #expect(names("usesSelf()").isEmpty)
        let record = Modules.record("usesSelf()", in: Modules.analysis("Lib", Self.source))
        #expect(record?.commonCoupling?.statics == ["S.total"])
    }

    @Test(
        "Heap's _checkInvariants parameters shadow the computed min and max",
        .enabled(if: FileManager.default.fileExists(atPath: home + "/GitHub_projects/swift-collections"))
    )
    func heapShadowing() {
        let files = Resolutions.files(under: Self.home + "/GitHub_projects/swift-collections/Sources/HeapModule")
        let resolved = Resolutions.names("HeapModule", files, function: "_checkInvariants(node:min:max:)")

        #expect(resolved.filter { ["min", "max"].contains($0.name) }.allSatisfy { $0.resolution == "local" })
        #expect(resolved.contains { $0.name == "min" })
    }

    @Test(
        "MarkedCircularBuffer's setter variable shadows the index method",
        .enabled(if: FileManager.default.fileExists(atPath: home + "/GitHub_projects/swift-nio"))
    )
    func nioShadowing() {
        let files = Resolutions.files(under: Self.home + "/GitHub_projects/swift-nio/Sources/NIOCore")
        let resolved = Resolutions.names(
            "NIOCore",
            files,
            function: "MarkedCircularBuffer::subscript(_: Range<Index>) -> SubSequence / { set }"
        )

        let uses = resolved.filter { $0.name == "index" }
        #expect(uses.isEmpty == false)
        #expect(uses.allSatisfy { $0.resolution == "local" })
    }

    @Test("12.1: a bare stored property in an extension is an own member")
    func extensionStoredProperty() {
        let resolved = Resolutions.names("Shop", CouplingSources.shop, function: "totalPrice.get")

        #expect(resolved.map { "\($0.name) \($0.resolution)" } == ["items own"])
    }

    @Test(
        "ContentView.body reaches its member inside a builder closure",
        .enabled(if: FileManager.default.fileExists(atPath: home + "/xcode_projects/SwiftProjectLint"))
    )
    func builderClosure() {
        let files = Resolutions.files(under: Self.home + "/xcode_projects/SwiftProjectLint/Sources/App")
        let resolved = Resolutions.names("App", files, function: "ContentView::var body: some View { get }")

        #expect(resolved.map { "\($0.name) \($0.resolution)" } == ["decoratedMainStack own"])
    }

    private func names(_ function: String) -> [String] {
        Resolutions.names("Lib", Self.source, function: function).map { "\($0.name) \($0.resolution)" }
    }
}
