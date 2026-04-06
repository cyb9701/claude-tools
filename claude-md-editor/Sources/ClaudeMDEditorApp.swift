import SwiftUI
import AppKit
import KeyboardShortcuts

// MARK: - 단축키 이름

extension KeyboardShortcuts.Name {
    /// 에디터 패널 토글 단축키.
    ///
    /// UserDefaults에 "toggleEditor" 키로 자동 저장되어 앱 재시작 후에도 유지된다.
    static let toggleEditor = Self("toggleEditor")
}

// MARK: - 앱 진입점

/// 앱 진입점.
///
/// SwiftUI App 프로토콜은 최소화하고, 모든 UI 제어는 AppDelegate에 위임한다.
/// Settings Scene은 "앱에 Scene이 없음" 경고를 방지하기 위한 최소 구성이다.
@main
struct ClaudeMDEditorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

// MARK: - AppDelegate

/// 메뉴바 아이콘, 에디터 패널, 글로벌 단축키를 관리한다.
///
/// 좌클릭: 에디터 패널 토글
/// 우클릭: 단축키 설정, 로그인 항목 토글, 종료 메뉴
/// NSPanel(floating level + hidesOnDeactivate = false)로 터미널 작업 중에도 패널이 유지된다.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem?
    private var panel: NSPanel?
    private var settingsMenu: NSMenu?
    let appState = AppState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPanel()
        setupKeyboardShortcut()
    }

    // MARK: - 설정

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }

        button.image = NSImage(
            systemSymbolName: "text.page.fill",
            accessibilityDescription: "Claude MD Editor"
        )
        // 좌클릭과 우클릭 이벤트를 모두 수신
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.action = #selector(statusButtonClicked(_:))
        button.target = self

        settingsMenu = buildSettingsMenu()
    }

    private func buildSettingsMenu() -> NSMenu {
        let menu = NSMenu()

        // 단축키 설정 행 (KeyboardShortcuts.Recorder SwiftUI 뷰를 NSMenuItem에 임베드)
        let recorderItem = NSMenuItem()
        let recorderView = NSHostingView(rootView:
            HStack {
                Text("단축키:")
                    .font(.system(size: 13))
                KeyboardShortcuts.Recorder("", name: .toggleEditor)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(width: 240)
        )
        recorderView.frame = NSRect(x: 0, y: 0, width: 240, height: 36)
        recorderItem.view = recorderView
        menu.addItem(recorderItem)

        menu.addItem(NSMenuItem.separator())

        let loginItem = NSMenuItem(
            title: "로그인 시 자동 실행",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        loginItem.state = appState.launchAtLogin ? .on : .off
        loginItem.target = self
        menu.addItem(loginItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(
            title: "종료",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))

        return menu
    }

    private func setupPanel() {
        let hostingView = NSHostingView(
            rootView: EditorView().environment(appState)
        )

        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            // nonactivatingPanel: 패널 클릭 시 이전 앱의 키 윈도우 상태 유지
            styleMask: [.titled, .closable, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel?.title = ""
        panel?.titlebarAppearsTransparent = true
        // floating level: 다른 앱 위에 항상 표시
        panel?.level = .floating
        panel?.contentView = hostingView
        panel?.center()
        panel?.isReleasedWhenClosed = false
        // false: 다른 앱 포커스 시 패널 자동 숨김 방지
        panel?.hidesOnDeactivate = false
        panel?.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    private func setupKeyboardShortcut() {
        // KeyboardShortcuts 콜백은 백그라운드 스레드에서 호출될 수 있으므로
        // @MainActor Task로 감싸 UI 업데이트 안전성 보장
        KeyboardShortcuts.onKeyUp(for: .toggleEditor) { [weak self] in
            Task { @MainActor in
                self?.togglePanel()
            }
        }
    }

    // MARK: - 액션

    @MainActor @objc private func statusButtonClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            // 우클릭: 설정 메뉴 표시
            syncLoginItemState()
            statusItem?.menu = settingsMenu
            statusItem?.button?.performClick(nil)
            // 메뉴 표시 후 즉시 제거해야 다음 좌클릭이 action을 다시 트리거함
            statusItem?.menu = nil
        } else {
            // 좌클릭: 에디터 패널 토글
            togglePanel()
        }
    }

    @MainActor @objc private func toggleLaunchAtLogin() {
        appState.launchAtLogin.toggle()
        syncLoginItemState()
    }

    // MARK: - Private

    func togglePanel() {
        if panel?.isVisible == true {
            panel?.orderOut(nil)
        } else {
            panel?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    /// 설정 메뉴의 "로그인 시 자동 실행" 체크 상태를 실제 등록 상태와 동기화한다.
    @MainActor private func syncLoginItemState() {
        settingsMenu?.items
            .first(where: { $0.title == "로그인 시 자동 실행" })?
            .state = appState.launchAtLogin ? .on : .off
    }
}
