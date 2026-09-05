// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RepeatKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "RepeatKit", targets: ["RepeatKit"]),
        .executable(name: "RepeatDemo", targets: ["RepeatDemo"]),
        .executable(name: "IngestDemo", targets: ["IngestDemo"])
    ],
    targets: [
        .target(name: "RepeatKit"),
        .executableTarget(name: "RepeatDemo", dependencies: ["RepeatKit"]),
        .executableTarget(name: "IngestDemo", dependencies: ["RepeatKit"])
    ]
)
