// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "HelloWord",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "HelloWord", targets: ["HelloWord"])
    ],
    targets: [
        .executableTarget(
            name: "HelloWord",
            path: "Sources/HelloWord",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreImage"),
                .linkedFramework("UniformTypeIdentifiers")
            ]
        )
    ]
)
