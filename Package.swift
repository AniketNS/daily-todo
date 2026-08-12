// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DailyTodo",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "DailyTodo",
            path: "Sources/DailyTodo"
        )
    ]
)
