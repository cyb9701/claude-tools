// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClaudeUsageBar",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "ClaudeUsageBar",
            path: "Sources",
            resources: [
                .process("icon_app.png"),
                .process("icon_status_bar.png")
            ],
            // @main 어트리뷰트가 SPM 실행 파일에서 동작하도록
            // 전체 소스를 라이브러리 모드로 파싱
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        )
    ]
)
