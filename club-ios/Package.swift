// swift-tools-version: 5.9
import PackageDescription
let package=Package(name:"ClubCore",products:[.library(name:"ClubCore",targets:["ClubCore"])],targets:[
    .target(name:"ClubCore",path:"Sources",exclude:["ClubApp.swift","ClubStore.swift","ClubSession.swift","ClubHome.swift","ClubMenu.swift","ClubRewards.swift","ClubAccount.swift"],sources:["ClubJSON.swift","ClubCore.swift"]),
    .testTarget(name:"ClubTests",dependencies:["ClubCore"],path:"Tests")
])
