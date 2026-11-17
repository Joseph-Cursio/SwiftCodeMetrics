//
//  PlatformModules.swift
//  SwiftCodeMetrics
//
//  The modules whose names the platform table holds, and the modules known
//  to re-export Foundation (Spec §7.4).
//

/// Fixed module sets.
enum PlatformModules {
    /// Harvested modules. XCTest counts only in files that import it.
    static let harvested: Set<String> = ["Dispatch", "Foundation", "Swift", "_Concurrency", "_StringProcessing"]
    /// XCTest.
    static let xcTest = "XCTest"
    /// Modules that make Foundation's `NS` classes visible.
    static let foundationExporters: Set<String> = ["AppKit", "Combine", "Foundation", "SwiftUI", "UIKit"]
}
