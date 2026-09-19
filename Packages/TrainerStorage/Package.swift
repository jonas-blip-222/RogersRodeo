// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "TrainerStorage",
    platforms: [.macOS(.v15), .iOS(.v17)],
    products: [.library(name: "TrainerStorage", targets: ["TrainerStorage"])],
    dependencies: [.package(path: "../TrainerCore")],
    targets: [
        .target(name: "TrainerStorage", dependencies: ["TrainerCore"]),
        .testTarget(name: "TrainerStorageTests", dependencies: ["TrainerStorage", "TrainerCore"])
    ], swiftLanguageModes: [.v6])
