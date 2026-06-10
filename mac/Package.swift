// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CursorGotchi",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "CursorGotchi",
            path: "Sources/CursorGotchi",
            linkerSettings: [
                .linkedLibrary("sqlite3"),
            ]
        ),
    ]
)
