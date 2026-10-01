// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "TouchGuard",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "TouchGuard", targets: ["TouchGuard"]),
    ],
    targets: [
        .executableTarget(name: "TouchGuard"),
        .testTarget(name: "TouchGuardTests", dependencies: ["TouchGuard"]),
    ]
)
