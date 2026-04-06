// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClaudeMDEditor",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0")
    ],
    targets: [
        .executableTarget(
            name: "ClaudeMDEditor",
            dependencies: ["KeyboardShortcuts"],
            path: "Sources",
            // @main 어트리뷰트가 SPM 실행 파일에서 동작하도록
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        )
    ]
)
