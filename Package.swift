// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "CircleToSearch",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .executable(
            name: "CircleToSearch",
            targets: ["CircleToSearch"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "CircleToSearch",
            path: "Sources"
        ),
    ]
)
