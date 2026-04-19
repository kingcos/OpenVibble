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
        .library(name: "NUSPeripheral", targets: ["NUSPeripheral"]),
        .library(name: "BuddyStorage", targets: ["BuddyStorage"]),
        .library(name: "BridgeRuntime", targets: ["BridgeRuntime"])
    ],
    targets: [
        .target(
            name: "BuddyProtocol"
        ),
        .target(
            name: "NUSPeripheral",
            dependencies: ["BuddyProtocol"]
        ),
        .target(
            name: "BuddyStorage",
            dependencies: ["BuddyProtocol"]
        ),
        .target(
            name: "BridgeRuntime",
            dependencies: ["BuddyProtocol", "BuddyStorage"]
        ),
        .testTarget(
            name: "BuddyProtocolTests",
            dependencies: ["BuddyProtocol"]
        )
    ]
)
