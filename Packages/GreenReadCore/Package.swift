// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GreenReadCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "GreenReadCore", targets: ["GreenReadCore"])
    ],
    targets: [
        .target(name: "GreenReadCore"),
        .testTarget(name: "GreenReadCoreTests", dependencies: ["GreenReadCore"])
    ]
)
