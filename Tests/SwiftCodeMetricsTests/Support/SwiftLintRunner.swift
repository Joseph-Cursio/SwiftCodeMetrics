//
//  SwiftLintRunner.swift
//  SwiftCodeMetricsTests
//
//  Runs SwiftLint's `cyclomatic_complexity` alone, with `warning: 0`, so it
//  reports every `func` and `init` scoring 1 or more (Spec §16).
//

import Foundation

/// Runs the installed `swiftlint` and reads its JSON report.
enum SwiftLintRunner {
    /// The SwiftLint release the SL rules were checked against.
    static let referenceVersion = "0.65.1"

    /// The `swiftlint` binary, if one is on a usual path.
    static let binary: URL? = ["/opt/homebrew/bin/swiftlint", "/usr/local/bin/swiftlint"]
        .map(URL.init(fileURLWithPath:))
        .first { FileManager.default.isExecutableFile(atPath: $0.path) }

    /// Whether the reference release is installed.
    static let isAvailable: Bool = binary.flatMap { try? run($0, ["version"]) }?
        .trimmingCharacters(in: .whitespacesAndNewlines) == referenceVersion

    /// SwiftLint's complexity for every reported function, keyed by file
    /// path and the line and column of the token SwiftLint reports at.
    static func complexities(
        of files: [String],
        ignoresCaseStatements: Bool
    ) throws -> [SwiftLintPosition: Int] {
        guard let binary else {
            return [:]
        }
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftCodeMetricsLint-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let config = directory.appendingPathComponent(".swiftlint.yml")
        try """
        only_rules: [cyclomatic_complexity]
        cyclomatic_complexity:
          warning: 0
          ignores_case_statements: \(ignoresCaseStatements)
        """.write(to: config, atomically: true, encoding: .utf8)

        var result: [SwiftLintPosition: Int] = [:]
        let batchSize = 400
        for start in stride(from: 0, to: files.count, by: batchSize) {
            let batch = Array(files[start..<min(start + batchSize, files.count)])
            let arguments = ["lint", "--quiet", "--no-cache", "--reporter", "json", "--config", config.path]
            let output = try run(binary, arguments + batch)
            for violation in try JSONDecoder().decode([SwiftLintViolation].self, from: Data(output.utf8)) {
                let column = violation.character ?? 0
                let position = SwiftLintPosition(file: violation.file, line: violation.line, column: column)
                result[position] = violation.complexity
            }
        }
        return result
    }

    /// Runs the binary and returns its standard output.
    private static func run(_ binary: URL, _ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = binary
        process.arguments = arguments
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(bytes: data, encoding: .utf8) ?? ""
    }
}
