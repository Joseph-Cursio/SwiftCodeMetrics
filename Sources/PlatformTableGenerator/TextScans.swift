//
//  TextScans.swift
//  PlatformTableGenerator
//
//  Line scans of Foundation's API notes and headers (Spec §7.4, sources 2
//  and 3). They are deliberately not a Clang parse.
//

import Foundation

/// Names read from Foundation's non-Swift files.
enum TextScans {
    /// `SwiftName:` values in the top-level `Typedefs:` and `Tags:` sections.
    static func renamedTypes(apinotes: String) -> Set<String> {
        var names: Set<String> = []
        var inSection = false
        for line in apinotes.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.first?.isLetter == true, line.hasSuffix(":") {
                if line == "SwiftVersions:" {
                    break
                }
                inSection = line == "Typedefs:" || line == "Tags:"
                continue
            }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard inSection, trimmed.hasPrefix("SwiftName:") else {
                continue
            }
            let name = trimmed.dropFirst("SwiftName:".count).trimmingCharacters(in: .whitespaces)
            if name.isEmpty == false, name.contains("(") == false {
                names.insert(name)
            }
        }
        return names
    }

    /// The function name of each `FOUNDATION_EXPORT` function declaration.
    static func exportedFunctions(header: String) -> Set<String> {
        var names: Set<String> = []
        for line in header.split(separator: "\n") where line.hasPrefix("FOUNDATION_EXPORT") {
            guard let open = line.firstIndex(of: "(") else {
                continue
            }
            let head = line[..<open].trimmingCharacters(in: .whitespaces)
            let name = head.reversed().prefix { $0.isLetter || $0.isNumber || $0 == "_" }.reversed()
            if name.isEmpty == false, head.hasSuffix(")") == false {
                names.insert(String(name))
            }
        }
        return names
    }
}
