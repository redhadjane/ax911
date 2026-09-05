// swift-tools-version: 5.9
import PackageDescription

// Portable contract/date tests only. The application is built by the Xcode project.
let package = Package(
    name: "HOPCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "HOPCore", targets: ["HOPCore"])],
    targets: [
        .target(name: "HOPCore", path: "Sources",
                exclude: ["HOPAPI.swift", "SessionStore.swift", "HOPEmployeeApp.swift",
                          "WorkspaceViews.swift", "WorkflowViews.swift", "ClubViews.swift", "StaffExperience.swift"],
                sources: ["HOPCore.swift"]),
        .testTarget(name: "HOPCoreTests", dependencies: ["HOPCore"], path: "Tests",
                    exclude: ["HOPAPITests.swift"],
                    sources: ["HOPCoreTests.swift"])
    ]
)
