// swift-tools-version: 5.10
import PackageDescription
let package = Package(name: "Saysee", platforms: [.macOS(.v14)], products: [.executable(name: "Saysee", targets: ["SayseeApp"])], dependencies: [
 .package(url:"https://github.com/Blaizzy/mlx-audio-swift.git",revision:"fe2c182f4da8115fe2b6b99c9a4d2048fbf9b1e6"),
 .package(url:"https://github.com/ml-explore/mlx-swift.git",from:"0.32.3")
], targets: [
 .target(name: "SayseeCore"),
 .executableTarget(name: "SayseeApp", dependencies: ["SayseeCore", .product(name:"MLXAudioSTT",package:"mlx-audio-swift"), .product(name:"MLX",package:"mlx-swift")]),
 .testTarget(name: "SayseeCoreTests", dependencies: ["SayseeCore"])
])
