// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HeyHumanly",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "HeyHumanly", targets: ["HeyHumanly"])],
    targets: [.executableTarget(name: "HeyHumanly", path: "Sources/WriteCoach")]
)
