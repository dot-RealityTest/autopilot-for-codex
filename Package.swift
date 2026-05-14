// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "CodexAutomationMenu",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "CodexAutomationMenu", targets: ["CodexAutomationMenu"])
    ],
    targets: [
        .executableTarget(name: "CodexAutomationMenu")
    ]
)
