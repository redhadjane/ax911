// swift-tools-version: 5.9
import PackageDescription

// Mac-hosted contracts and mocked transport/store tests, without an iOS simulator.
let package = Package(
    name: "HOPCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "HOPCore", targets: ["HOPCore"])],
    targets: [
        .target(name: "HOPCore", path: "Sources",
                exclude: ["SessionStore.swift", "HOPEmployeeApp.swift", "MessagingViews.swift",
                          "WorkspaceViews.swift", "WorkflowViews.swift", "ClubViews.swift", "StaffExperience.swift"],
                sources: ["HOPCore.swift", "HOPAPI.swift", "StaffMessagesCore.swift", "MessagingStore.swift"]),
        .testTarget(name: "HOPCoreTests", dependencies: ["HOPCore"], path: "Tests",
                    sources: ["HOPCoreTests.swift", "HOPAPITests.swift", "StaffMessagesTests.swift"])
    ]
)
