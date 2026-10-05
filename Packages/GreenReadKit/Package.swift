// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GreenReadKit",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        .library(name: "AppFeature", targets: ["AppFeature"]),
        .library(name: "Clients", targets: ["Clients"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "Models", targets: ["Models"]),
    ],
    dependencies: [
        .package(path: "../GreenReadCore"),
        .package(url: "https://github.com/pointfreeco/sqlite-data", from: "1.12.0"),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.26.0"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.17.0"),
        .package(url: "https://github.com/pointfreeco/swift-sharing", from: "2.10.0"),
    ],
    targets: [
        // MARK: Foundation

        .target(
            name: "DesignSystem",
            dependencies: [
                .product(name: "GreenReadCore", package: "GreenReadCore"),
            ],
            resources: [
                .process("Resources"),
            ]
        ),
        .target(
            name: "Models",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "GreenReadCore", package: "GreenReadCore"),
                .product(name: "Sharing", package: "swift-sharing"),
                .product(name: "SQLiteData", package: "sqlite-data"),
            ]
        ),
        .target(
            name: "Clients",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "DependenciesMacros", package: "swift-dependencies"),
                .product(name: "GreenReadCore", package: "GreenReadCore"),
            ]
        ),

        // MARK: Features

        .target(
            name: "AppFeature",
            dependencies: [
                "DesignSystem",
                "Models",
                "QuickReadFeature",
                .product(name: "GreenReadCore", package: "GreenReadCore"),
                "DrillsFeature",
                "HomeFeature",
                "OnboardingFeature",
                "SettingsFeature",
                "StatsFeature",
                "TempoFeature",
                "ToolFeature",
            ]
        ),
        .target(
            name: "DrillsFeature",
            dependencies: [
                "DesignSystem",
                "Models",
                "TempoFeature",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .target(
            name: "HomeFeature",
            dependencies: [
                "DesignSystem",
                "DrillsFeature",
                "Models",
                .product(name: "SQLiteData", package: "sqlite-data"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .target(
            name: "OnboardingFeature",
            dependencies: [
                "DesignSystem",
                "Models",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .target(
            name: "QuickReadFeature",
            dependencies: [
                "Clients",
                "DesignSystem",
                "Models",
                .product(name: "GreenReadCore", package: "GreenReadCore"),
                .product(name: "SQLiteData", package: "sqlite-data"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .target(
            name: "ScanFeature",
            dependencies: [
                "Clients",
                "DesignSystem",
                "Models",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .target(
            name: "SettingsFeature",
            dependencies: [
                "DesignSystem",
                .product(name: "GreenReadCore", package: "GreenReadCore"),
                "Models",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .target(
            name: "StatsFeature",
            dependencies: [
                "DesignSystem",
                "Models",
                .product(name: "GreenReadCore", package: "GreenReadCore"),
                .product(name: "SQLiteData", package: "sqlite-data"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .target(
            name: "TempoFeature",
            dependencies: [
                "Clients",
                "DesignSystem",
                "Models",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .target(
            name: "ToolFeature",
            dependencies: [
                "DesignSystem",
                "QuickReadFeature",
                "ScanFeature",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),

        // MARK: Tests

        .testTarget(
            name: "AppFeatureTests",
            dependencies: [
                "AppFeature",
                .product(name: "DependenciesTestSupport", package: "swift-dependencies"),
            ]
        ),
        .testTarget(
            name: "QuickReadFeatureTests",
            dependencies: [
                "QuickReadFeature",
                .product(name: "DependenciesTestSupport", package: "swift-dependencies"),
            ]
        ),
        .testTarget(
            name: "SettingsFeatureTests",
            dependencies: [
                "SettingsFeature",
                .product(name: "DependenciesTestSupport", package: "swift-dependencies"),
            ]
        ),
        .testTarget(
            name: "ModelsTests",
            dependencies: [
                "Models",
                .product(name: "DependenciesTestSupport", package: "swift-dependencies"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
