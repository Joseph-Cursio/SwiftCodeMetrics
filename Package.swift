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
            resources: [.copy("Resources/PlatformTable.json")],
            swiftSettings: kSwiftSettings
        ),
        // Builds Resources/PlatformTable.json from the SDK (Spec §7.4). Not
        // linked by the library; run it when the SDK changes.
        .executableTarget(
            name: "PlatformTableGenerator",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax")
            ],
            swiftSettings: kSwiftSettings
        ),
        .testTarget(
            name: "SwiftCodeMetricsTests",
            dependencies: [
                "SwiftCodeMetrics",
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftOperators", package: "swift-syntax")
            ],
            resources: [.copy("Fixtures"), .copy("Golden")],
            swiftSettings: kSwiftSettings
        )
    ]
)
