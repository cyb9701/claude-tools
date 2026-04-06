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
                // @main 어트리뷰트가 SPM 실행 파일에서 동작하도록
                // 전체 소스를 라이브러리 모드로 파싱
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
