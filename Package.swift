// swift-tools-version: 6.2
import PackageDescription

let kSwiftSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6)
]

let kPackage = Package(
    name: "SwiftCodeMetrics",
    platforms: [.macOS(.v14)],
    products: [
        .library(
            name: "SwiftCodeMetrics",
            targets: ["SwiftCodeMetrics"]
        )
    ],
    dependencies: [
        // Pinned exactly to match SwiftStats and SwiftProjectLint, the two
        // consumers (Docs/Spec.md §1.2).
        .package(
            url: "https://github.com/swiftlang/swift-syntax.git",
            exact: "603.0.2"
        )
    ],
    targets: [
        .target(
            name: "SwiftCodeMetrics",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax")
            ],
            swiftSettings: kSwiftSettings
        )
    ]
)
