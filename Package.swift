// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "AutopilotForCodex",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "AutopilotForCodex", targets: ["AutopilotForCodex"])
    ],
    targets: [
        .executableTarget(name: "AutopilotForCodex")
    ]
)
