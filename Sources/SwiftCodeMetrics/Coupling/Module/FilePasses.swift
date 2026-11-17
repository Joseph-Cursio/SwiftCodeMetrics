//
//  FilePasses.swift
//  SwiftCodeMetrics
//
//  Runs the file pass over a module's files in parallel. Each file pass
//  reads only its own immutable tree (Spec §13.1: "safe to run in parallel").
//

import Foundation

/// Parallel file passes.
enum FilePasses {
    /// The file pass of every file, in input order.
    static func run(_ files: [SourceFileInput], module: String, options: MetricsOptions) -> [FileAnalysis] {
        let results = ResultSlots<FileAnalysis>(count: files.count)
        DispatchQueue.concurrentPerform(iterations: files.count) { index in
            results.store(SwiftCodeMetrics.analyzeFile(files[index], module: module, options: options), at: index)
        }
        return results.values
    }
}
