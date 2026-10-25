// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ZenWaveContentStudio",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "ZenWaveStudio", targets: ["ZenWaveStudio"])],
    targets: [
        .systemLibrary(name: "CSQLite"),
        .executableTarget(name: "ZenWaveStudio", dependencies: ["CSQLite"], resources: [.copy("Resources")]),
        .testTarget(name: "ZenWaveStudioTests", dependencies: ["ZenWaveStudio"], resources: [.copy("Fixtures")])
    ]
)
