//
//  ModuleInput.swift
//  SwiftCodeMetrics
//
//  Every file of one module, as the caller lists them (Spec §1.4).
//

/// One module's parsed files.
public struct ModuleInput: Sendable {
    /// The Swift module name that `import` declarations use.
    public var name: String
    /// The files; the library never walks directories.
    public var files: [SourceFileInput]
    /// Whether the module is a test target.
    public var isTest: Bool

    /// Creates an input.
    public init(name: String, files: [SourceFileInput], isTest: Bool) {
        self.name = name
        self.files = files
        self.isTest = isTest
    }
}
