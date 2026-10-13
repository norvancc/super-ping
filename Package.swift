// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PingAgent", platforms: [.macOS(.v13)],
    products: [.executable(name: "PingAgent", targets: ["PingAgent"])],
    targets: [
        .target(name: "PingCore"),
        .executableTarget(name: "PingAgent", dependencies: ["PingCore"], resources: [.copy("Resources")]),
        .testTarget(name: "PingCoreTests", dependencies: ["PingCore"])
    ]
)
