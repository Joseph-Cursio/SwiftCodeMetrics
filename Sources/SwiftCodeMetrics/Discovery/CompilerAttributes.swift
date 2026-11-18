//
//  CompilerAttributes.swift
//  SwiftCodeMetrics
//
//  The compiler's declaration attributes that start with an uppercase
//  letter. They name no type, so Spec §9.4 excludes them from coupling.
//

/// Built-in uppercase attributes.
enum CompilerAttributes {
    /// The attribute names, as written after `@`.
    static let names: Set<String> = [
        "GKInspectable",
        "IBAction",
        "IBDesignable",
        "IBInspectable",
        "IBOutlet",
        "IBSegueAction",
        "NSApplicationMain",
        "NSCopying",
        "NSManaged",
        "UIApplicationMain"
    ]
}
