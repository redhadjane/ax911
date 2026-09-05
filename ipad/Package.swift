// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "CommandPolicy", products: [.library(name: "CommandPolicy", targets: ["CommandPolicy"])], targets: [
    .target(name: "CommandPolicy", path: "Sources", sources: ["CommandPolicy.swift"]),
    .testTarget(name: "CommandPolicyTests", dependencies: ["CommandPolicy"], path: "Tests")
])
