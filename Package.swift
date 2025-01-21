// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "ChessCore",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .library(name: "ChessCore", targets: ["ChessCore"])
  ],
  targets: [
    .target(name: "ChessCore", dependencies: []),
    .testTarget(name: "ChessCoreTests", dependencies: ["ChessCore"])
  ]
)
