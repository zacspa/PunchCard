// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PunchCard",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "PunchCardLib",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/PunchCardLib"
        ),
        .executableTarget(
            name: "punchcard",
            dependencies: ["PunchCardLib"],
            path: "Sources/PunchCardCLI"
        ),
        .testTarget(
            name: "PunchCardTests",
            dependencies: ["PunchCardLib"]
        ),
    ]
)
