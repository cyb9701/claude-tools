// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClaudePromptPad",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0")
    ],
    targets: [
        // 순수 로직 라이브러리 — 단위 테스트 가능
        .target(
            name: "ClipboardHistoryKit",
            dependencies: [],
            path: "ClipboardHistoryKit"
        ),
        .executableTarget(
            name: "ClaudePromptPad",
            dependencies: ["KeyboardShortcuts", "ClipboardHistoryKit"],
            path: "Sources",
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        ),
        .testTarget(
            name: "ClaudePromptPadTests",
            dependencies: ["ClipboardHistoryKit"],
            path: "Tests"
        )
    ]
)
