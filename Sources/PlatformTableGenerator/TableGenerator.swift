//
//  TableGenerator.swift
//  PlatformTableGenerator
//
//  Harvests the selected SDK's interfaces, API notes and headers, and
//  writes the platform table as JSON.
//

import Foundation
import SwiftParser

/// The generator's entry point and helpers.
enum TableGenerator {
    /// The output path when none is given on the command line.
    private static let defaultOutput = "Sources/SwiftCodeMetrics/Resources/PlatformTable.json"
    /// The interface file name inside each `.swiftmodule`.
    private static let interfaceName = "arm64e-apple-macos.swiftinterface"

    /// Writes the platform table to the path given as the first argument,
    /// or to the default resource path.
    static func run() throws {
        let output = CommandLine.arguments.dropFirst().first ?? defaultOutput
        let sdk = try xcrun(["--show-sdk-path"])
        let platform = try xcrun(["--show-sdk-platform-path"])
        let foundation = sdk + "/System/Library/Frameworks/Foundation.framework"
        let interfaces = ["Swift", "_Concurrency", "_StringProcessing", "Dispatch"]
            .map { "\(sdk)/usr/lib/swift/\($0).swiftmodule/\(interfaceName)" }
            + ["\(foundation)/Modules/Foundation.swiftmodule/\(interfaceName)"]

        var types: Set<String> = []
        var protocols: Set<String> = []
        var functions: Set<String> = []

        for path in interfaces {
            let harvester = try harvest(path)
            types.formUnion(harvester.types)
            protocols.formUnion(harvester.protocols)
            functions.formUnion(harvester.functions)
        }
        let apinotes = try String(contentsOfFile: "\(foundation)/Headers/Foundation.apinotes", encoding: .utf8)
        types.formUnion(TextScans.renamedTypes(apinotes: apinotes))
        let headers = try FileManager.default.contentsOfDirectory(atPath: "\(foundation)/Headers")
        for header in headers where header.hasSuffix(".h") {
            let text = try String(contentsOfFile: "\(foundation)/Headers/\(header)", encoding: .utf8)
            functions.formUnion(TextScans.exportedFunctions(header: text))
        }
        let xcTest = try harvest("\(platform)/Developer/usr/lib/XCTest.swiftmodule/\(interfaceName)")

        var table = [String: Any]()

        table["sdkVersion"] = try xcrun(["--show-sdk-version"])
        table["types"] = types.sorted()
        table["protocols"] = protocols.sorted()
        table["freeFunctions"] = functions.sorted()
        table["xcTest"] = xcTest.types.sorted()
        table["xcTestFreeFunctions"] = xcTest.functions.sorted()
        let data = try JSONSerialization.data(withJSONObject: table, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: URL(fileURLWithPath: output))
        let xcTestCount = xcTest.types.count + xcTest.functions.count
        print(
            "wrote \(output): \(types.count) types, \(protocols.count) protocols, "
                + "\(functions.count) functions, \(xcTestCount) XCTest names"
        )
    }

    /// Runs `xcrun` and returns its trimmed output.
    private static func xcrun(_ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (String(bytes: data, encoding: .utf8) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Harvests one interface file.
    private static func harvest(_ path: String) throws -> InterfaceHarvester {
        let source = try String(contentsOfFile: path, encoding: .utf8)
        let harvester = InterfaceHarvester()
        harvester.walk(Parser.parse(source: source))
        return harvester
    }
}
