// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Benchmarks",
    platforms: [.macOS(.v10_15)],
    dependencies: [
        .package(url: "https://github.com/attaswift/BigInt.git", from: "5.7.0")
    ],
    targets: [
        .executableTarget(
            name: "Benchmarks",
            dependencies: ["BigInt"],
            swiftSettings: [
                // .unsafeFlags(["-cross-module-optimization"]),
            ]
        )
    ]
)