//
//  PlatformTable.swift
//  SwiftCodeMetrics
//
//  Names the standard library, Swift concurrency, string processing,
//  Dispatch, Foundation and XCTest declare (Spec §7.4). Generated from the
//  SDK by the PlatformTableGenerator target and bundled as a resource.
//

import Foundation

/// The platform type and free-function names.
public struct PlatformTable: Sendable, Codable, Hashable {
    /// The table generated from the SDK this release was built with.
    public static let bundled: Self = {
        guard let url = Bundle.module.url(forResource: "PlatformTable", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let table = try? JSONDecoder().decode(Self.self, from: data) else {
            return Self(
                sdkVersion: "missing",
                types: [],
                protocols: [],
                freeFunctions: [],
                xcTest: [],
                xcTestFreeFunctions: []
            )
        }
        return table
    }()

    /// The SDK version the table came from, reported as `MetricsVersion.platformTable`.
    public var sdkVersion: String
    /// Type names: top-level names, and dotted paths for nested types (`String.Index`).
    public var types: Set<String>
    /// The protocols among `types`.
    public var protocols: Set<String>
    /// Top-level function names.
    public var freeFunctions: Set<String>
    /// XCTest type names, used only in files that import XCTest.
    public var xcTest: Set<String>
    /// XCTest function names, used only in files that import XCTest.
    public var xcTestFreeFunctions: Set<String>

    /// Creates a table.
    public init(
        sdkVersion: String,
        types: Set<String>,
        protocols: Set<String>,
        freeFunctions: Set<String>,
        xcTest: Set<String>,
        xcTestFreeFunctions: Set<String>
    ) {
        self.sdkVersion = sdkVersion
        self.types = types
        self.protocols = protocols
        self.freeFunctions = freeFunctions
        self.xcTest = xcTest
        self.xcTestFreeFunctions = xcTestFreeFunctions
    }

    /// Encodes every set as a sorted array, so the bundled file is stable.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sdkVersion, forKey: .sdkVersion)
        try container.encode(types.sorted(), forKey: .types)
        try container.encode(protocols.sorted(), forKey: .protocols)
        try container.encode(freeFunctions.sorted(), forKey: .freeFunctions)
        try container.encode(xcTest.sorted(), forKey: .xcTest)
        try container.encode(xcTestFreeFunctions.sorted(), forKey: .xcTestFreeFunctions)
    }
}
