import SwiftUI

/// 앱 진입점.
///
/// MenuBarExtra를 사용하여 macOS 메뉴바 전용 앱으로 동작한다.
/// LSUIElement = YES 설정으로 Dock 아이콘 없이 실행된다.
@main
struct ClaudeUsageBarApp: App {

    @State private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environment(appState)
        } label: {
            MenuBarLabelView(appState: appState)
        }
        .menuBarExtraStyle(.window)
    }
}
