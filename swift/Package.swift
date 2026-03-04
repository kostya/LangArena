// swift-tools-version:5.9
import PackageDescription

let package = Package(
  name: "Benchmarks",
  platforms: [.macOS(.v10_15)],
  dependencies: [
    .package(url: "https://github.com/attaswift/BigInt.git", from: "5.7.0"),
    .package(url: "https://github.com/swiftcsv/SwiftCSV.git", from: "0.10.0")
  ],
  targets: [
    .executableTarget(
      name: "Benchmarks",
      dependencies: [
        "BigInt",
        .product(name: "SwiftCSV", package: "SwiftCSV")
      ],
      swiftSettings: [
        // .unsafeFlags(["-cross-module-optimization"]),
      ]
    )
  ]
)