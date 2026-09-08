// swift-tools-version: 5.9
import PackageDescription

let package = Package(name:"AcademyCore", platforms:[.macOS(.v13)], products:[.library(name:"AcademyCore",targets:["AcademyCore"])], targets:[
    .target(name:"AcademyCore",path:"Sources",exclude:["AcademyApp.swift","AcademyDesign.swift","AcademyHome.swift","AcademyLibrary.swift","AcademyStore.swift","AcademyStudy.swift"],sources:["AcademyCore.swift"]),
    .testTarget(name:"AcademyTests",dependencies:["AcademyCore"],path:"Tests")
])
