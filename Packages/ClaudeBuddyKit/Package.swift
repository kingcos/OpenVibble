// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ClaudeBuddyKit",
    platforms: [
        .iOS(.v18),
        .macOS(.v14)
    ],
    products: [
        .library(name: "BuddyProtocol", targets: ["BuddyProtocol"]),
        .library(name: "NUSPeripheral", targets: ["NUSPeripheral"])
    ],
    targets: [
        .target(
            name: "BuddyProtocol"
        ),
        .target(
            name: "NUSPeripheral",
            dependencies: ["BuddyProtocol"]
        ),
        .testTarget(
            name: "BuddyProtocolTests",
            dependencies: ["BuddyProtocol"]
        )
    ]
)
