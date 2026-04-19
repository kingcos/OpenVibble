// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ClaudeBuddyKit",
    platforms: [
        .iOS(.v18),
        .macOS(.v14)
    ],
    products: [
        .library(name: "BuddyProtocol", targets: ["BuddyProtocol"])
    ],
    targets: [
        .target(
            name: "BuddyProtocol"
        ),
        .testTarget(
            name: "BuddyProtocolTests",
            dependencies: ["BuddyProtocol"]
        )
    ]
)
