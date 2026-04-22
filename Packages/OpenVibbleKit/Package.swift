// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OpenVibbleKit",
    platforms: [
        .iOS(.v18),
        .macOS(.v14)
    ],
    products: [
        .library(name: "BuddyProtocol", targets: ["BuddyProtocol"]),
        .library(name: "NUSPeripheral", targets: ["NUSPeripheral"]),
        .library(name: "NUSCentral", targets: ["NUSCentral"]),
        .library(name: "BuddyStorage", targets: ["BuddyStorage"]),
        .library(name: "BridgeRuntime", targets: ["BridgeRuntime"]),
        .library(name: "BuddyPersona", targets: ["BuddyPersona"]),
        .library(name: "BuddyStats", targets: ["BuddyStats"]),
        .library(name: "BuddyUI", targets: ["BuddyUI"]),
        .library(name: "HookBridge", targets: ["HookBridge"])
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
            name: "NUSCentral",
            dependencies: ["BuddyProtocol"]
        ),
        .target(
            name: "BuddyStorage",
            dependencies: ["BuddyProtocol"]
        ),
        .target(
            name: "BridgeRuntime",
            dependencies: ["BuddyProtocol", "BuddyStorage", "BuddyPersona"]
        ),
        .target(
            name: "BuddyPersona",
            dependencies: ["BuddyProtocol"]
        ),
        .target(
            name: "BuddyStats",
            dependencies: ["BuddyProtocol"]
        ),
        .target(
            name: "BuddyUI",
            dependencies: ["BuddyPersona", "BuddyStats", "BuddyProtocol"]
        ),
        .target(
            name: "HookBridge",
            dependencies: ["BuddyProtocol"]
        ),
        .testTarget(
            name: "BuddyProtocolTests",
            dependencies: ["BuddyProtocol"]
        ),
        .testTarget(
            name: "BuddyStorageTests",
            dependencies: ["BuddyStorage", "BuddyProtocol"]
        ),
        .testTarget(
            name: "BridgeRuntimeTests",
            dependencies: ["BridgeRuntime", "BuddyStorage", "BuddyProtocol", "BuddyPersona"]
        ),
        .testTarget(
            name: "BuddyPersonaTests",
            dependencies: ["BuddyPersona", "BuddyProtocol"]
        ),
        .testTarget(
            name: "BuddyStatsTests",
            dependencies: ["BuddyStats", "BuddyProtocol"]
        ),
        .testTarget(
            name: "NUSCentralTests",
            dependencies: ["NUSCentral", "BuddyProtocol"]
        ),
        .testTarget(
            name: "HookBridgeTests",
            dependencies: ["HookBridge", "BuddyProtocol"]
        )
    ]
)
