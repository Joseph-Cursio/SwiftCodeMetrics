//
//  CorpusTypeTests.swift
//  SwiftCodeMetricsTests
//
//  Spec §16 v0.3 corpus checks: the "Part B" column of §12.7 for all seven
//  types, on the code they were hand-counted from. Each test is skipped
//  when its corpus is not on this machine.
//

import Foundation
import SwiftCodeMetrics
import Testing

@Suite("Corpus checks: types (Spec §12.7)")
struct CorpusTypeTests {
    private static let home = FileManager.default.homeDirectoryForCurrentUser.path
    private static let syncUps = home + "/GitHub_projects/swift-composable-architecture/Examples/SyncUps/SyncUps"
    private static let spl = home + "/xcode_projects/SwiftProjectLint/Sources/App"
    private static let posix = home + "/GitHub_projects/swift-nio/Sources/NIOPosix"
    private static let stats = home + "/xcode_projects/SwiftStats/Sources/SwiftStatsCore"
    private static let heap = home + "/GitHub_projects/swift-collections/Sources/HeapModule"
    private static let core = home + "/GitHub_projects/swift-nio/Sources/NIOCore"
    private static let grdb = home + "/GitHub_projects/GRDB.swift/GRDB"

    private static func exists(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }

    @Test(
        "TCA SyncUpDetail: macro, Ce to SyncUpForm.State, ceFamily 2, unresolved extension",
        .enabled(if: exists(syncUps))
    )
    func syncUpDetail() throws {
        let analysis = Modules.analysis("SyncUps", Resolutions.files(under: Self.syncUps))
        let detail = try #require(Modules.type("SyncUpDetail", in: analysis))
        let destination = try #require(Modules.type("SyncUpDetail.Destination", in: analysis))

        #expect(detail.sizes.noa == 3)
        #expect(detail.sizes.nom == 1)
        #expect(detail.cohesion.nullReason == .fewerThanTwoMembers)
        #expect(detail.hasKnownAttachedMacro)
        #expect(Modules.targets(of: detail, in: analysis) == ["SyncUpForm.State"])
        #expect(Modules.targets(of: destination, in: analysis) == ["SyncUpForm"])
        #expect(analysis.typeEdges.first { $0.source == destination.key }?.kinds == [.casePayload])
        #expect(detail.coupling.ceFamily == 2)
        #expect(analysis.unresolvedExtensions.map(\.extendedType).contains("SyncUpDetail.Destination.State"))
    }

    @Test("SwiftProjectLint ContentView: LCOM4 1, Ce 11 = ceView 7 + ceConcrete 4", .enabled(if: exists(spl)))
    func contentView() throws {
        let analysis = Modules.analysis("App", Resolutions.files(under: Self.spl))
        let view = try #require(Modules.type("ContentView", in: analysis))

        #expect(view.sizes.noa == 2)
        #expect(view.sizes.nom == 9)
        #expect(view.cohesion.nodeCount == 8)
        #expect(view.cohesion.lcom4 == 1)
        #expect(view.cohesion.isolatedMembers.isEmpty)
        #expect(view.coupling.ceTotal == 11)
        #expect(view.coupling.ceView == 7)
        #expect(view.coupling.ceConcrete == 4)
        let concrete = analysis.typeEdges.filter { $0.source == view.key && $0.targetClass == .concrete }
        #expect(Set(concrete.map { $0.target.path.joined(separator: ".") }) == [
            "ContentViewModel", "RuleSelectionConfig", "RuleSelectionWindowController", "SystemComponents"
        ])
    }

    @Test("swift-nio ServerSocketChannel: superclass attributes give LCOM4 1, 10 isolated", .enabled(if: exists(posix)))
    func serverSocketChannel() throws {
        let analysis = Modules.analysis("NIOPosix", Resolutions.files(under: Self.posix))
        let channel = try #require(Modules.type("ServerSocketChannel", in: analysis))

        #expect(channel.superclass?.path == ["BaseSocketChannel"])
        #expect(channel.sizes.noa == 2)
        #expect(channel.cohesion.attributeCount > channel.sizes.noa)
        #expect(channel.cohesion.lcom4 == 1)
        #expect(channel.cohesion.isolatedMembers.count == 10)
        #expect(channel.cohesion.components.first?.attributes.contains("socket") == true)
    }

    @Test("SwiftStats FunctionCollector: LCOM4 1, two isolated, Ce 14 with 3 namespaces", .enabled(if: exists(stats)))
    func functionCollector() throws {
        let analysis = Modules.analysis("SwiftStatsCore", Resolutions.files(under: Self.stats))
        let collector = try #require(Modules.type("FunctionCollector", in: analysis))

        #expect(collector.sizes.noa == 8)
        #expect(collector.sizes.nom == 55)
        #expect(collector.cohesion.nodeCount == 46)
        #expect(collector.cohesion.lcom4 == 1)
        #expect(collector.cohesion.isolatedMembers.map(Modules.memberName) == [
            "func visit(_: MacroExpansionExprSyntax) -> SyntaxVisitorContinueKind",
            "func visit(_: MacroExpansionDeclSyntax) -> SyntaxVisitorContinueKind"
        ])
        #expect(collector.coupling.ceTotal == 14)
        #expect(collector.coupling.ceConcrete == 11)
        #expect(collector.coupling.ceNamespace == 3)
        let namespaces = analysis.typeEdges.filter { $0.source == collector.key && $0.targetClass == .namespace }
        #expect(Set(namespaces.map { $0.target.path.joined(separator: ".") }) == [
            "BodyHash", "CanonicalText", "DeclarationRenderer"
        ])
    }

    @Test("swift-collections Heap: NOM 27 with #if variants merged, Ce 1", .enabled(if: exists(heap)))
    func heapType() throws {
        let analysis = Modules.analysis("HeapModule", Resolutions.files(under: Self.heap))
        let type = try #require(Modules.type("Heap", in: analysis))

        #expect(type.sizes.noa == 1)
        #expect(type.sizes.nom == 27)
        #expect(type.sizes.instanceMembers == 25)
        #expect(type.sizes.initialisers == 4)
        #expect(type.sizes.staticMembers == 2)
        #expect(type.cohesion.lcom4 == 1)
        #expect(Modules.targets(of: type, in: analysis) == ["_HeapNode"])
    }

    @Test("swift-nio MarkedCircularBuffer: Ce 2 to a type and its nested Index", .enabled(if: exists(core)))
    func markedCircularBuffer() throws {
        let analysis = Modules.analysis("NIOCore", Resolutions.files(under: Self.core))
        let buffer = try #require(Modules.type("MarkedCircularBuffer", in: analysis))

        #expect(buffer.sizes.noa == 2)
        #expect(buffer.sizes.nom == 21)
        #expect(buffer.cohesion.nodeCount == 19)
        #expect(buffer.cohesion.lcom4 == 1)
        #expect(Modules.targets(of: buffer, in: analysis).sorted() == ["CircularBuffer", "CircularBuffer.Index"])
        #expect(buffer.coupling.ceConcrete == 2)
        #expect(buffer.coupling.ceFamily == 1)
        #expect(buffer.cohesion.unresolvedMemberRefs == ["formIndex"])
    }

    @Test("GRDB DispatchQueueActor: nonisolated unownedExecutor stays a node", .enabled(if: exists(grdb)))
    func dispatchQueueActor() throws {
        let analysis = Modules.analysis("GRDB", Resolutions.files(under: Self.grdb))
        let actor = try #require(Modules.type("DispatchQueueActor", in: analysis))

        #expect(actor.cohesion.nodeCount == 2)
        #expect(actor.cohesion.lcom4 == 1)
        #expect(actor.cohesion.isolatedMembers.map(Modules.memberName).first?.hasPrefix("func execute") == true)
    }
}
