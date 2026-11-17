//
//  CorpusCouplingTests.swift
//  SwiftCodeMetricsTests
//
//  Spec §16 v0.2 corpus checks: the function-level figures of §12.7 on the
//  real code they were hand-counted from. Each test is skipped when its
//  corpus is not on this machine.
//

import Foundation
import SwiftCodeMetrics
import Testing

@Suite("Corpus checks (Spec §12.7)")
struct CorpusCouplingTests {
    private static let home = FileManager.default.homeDirectoryForCurrentUser.path
    private static let syncUps = home + "/GitHub_projects/swift-composable-architecture/Examples/SyncUps/SyncUps"
    private static let spl = home + "/xcode_projects/SwiftProjectLint/Sources/App"
    private static let heap = home + "/GitHub_projects/swift-collections/Sources/HeapModule"

    private static func exists(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }

    @Test("TCA SyncUpDetail.body: patterns excluded, implicit members and chains split", .enabled(if: exists(syncUps)))
    func syncUpDetail() throws {
        let analysis = Modules.analysis("SyncUps", Resolutions.files(under: Self.syncUps))
        let body = try #require(analysis.functions.first { $0.key.description.contains("SyncUpDetail::var body") })

        #expect(body.fanOut?.fanOut == 8)
        #expect(body.fanOut?.fanOutImplicitMember == 6)
        #expect(Modules.keys(body, .implicitMember).map { $0.split(separator: "(").first ?? "" } == [
            "..alert", "..delegate", "..edit", "..run", "..send", "..startMeeting"
        ])
        #expect(Modules.keys(body, .chain) == ["chain.ifLet(_:action:)"])
    }

    @Test("SwiftProjectLint ContentView: decoratedMainStack's chains, and one singleton", .enabled(if: exists(spl)))
    func contentView() throws {
        let analysis = Modules.analysis("App", Resolutions.files(under: Self.spl))
        let records = analysis.functions.filter { $0.key.description.contains("App::ContentView::") }
        let stack = try #require(records.first { $0.name == "decoratedMainStack.get" })

        #expect(stack.fanOut?.fanOut == 8)
        #expect(stack.fanOut?.fanOutChained == 7)
        #expect(records.flatMap { $0.commonCoupling?.singletons ?? [] } == ["RuleSelectionWindowController.shared"])
    }

    @Test(
        "swift-collections Heap.popMin: _HeapNode.root is a computed static, not a singleton",
        .enabled(if: exists(heap))
    )
    func heapPopMin() throws {
        let analysis = Modules.analysis("HeapModule", Resolutions.files(under: Self.heap))
        let popMin = try #require(
            analysis.functions.first { $0.key.description == "HeapModule::Heap::func popMin() -> Element?" }
        )

        #expect(popMin.commonCoupling?.singletonRefs == 0)
        #expect(popMin.commonCoupling?.statics.contains("_HeapNode.root") == true)
    }
}
