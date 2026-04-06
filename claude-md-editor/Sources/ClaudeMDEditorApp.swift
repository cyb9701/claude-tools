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

// MARK: - 단축키 설정 뷰

/// 단축키 설정 패널에 표시되는 뷰.
///
/// NSMenuItem에 NSHostingView를 임베드하는 방식은 macOS에서 불안정하므로
/// 별도 NSPanel로 분리하여 신뢰성을 확보한다.
struct ShortcutSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent("패널 열기") {
                KeyboardShortcuts.Recorder("", name: .toggleEditor)
            }
        }
        .padding(20)
        .frame(width: 280)
    }
}

// MARK: - AppDelegate

/// 메뉴바 아이콘, 에디터 패널, 글로벌 단축키를 관리한다.
///
/// 좌클릭: 에디터 패널을 메뉴바 아이콘 바로 아래에 배치 후 표시/숨김 토글
/// 우클릭: 단축키 설정, 로그인 항목 토글, 종료 메뉴
/// NSPanel(floating level + hidesOnDeactivate = false)로 터미널 작업 중에도 패널이 유지된다.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem?
    private var panel: NSPanel?
    private var shortcutSettingsPanel: NSPanel?
    private var settingsMenu: NSMenu?
    let appState = AppState()

    // 메뉴 항목을 tag로 식별하기 위한 상수.
    //
    // title 문자열 기반 검색은 UI 텍스트 변경 시 조용히 깨지므로 정수 tag를 사용한다.
    private enum MenuItemTag {
        static let launchAtLogin = 100
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPanel()
        setupKeyboardShortcut()
        // 복사 버튼 클릭 시 패널이 즉시 닫히도록 콜백 주입.
        appState.onClosePanel = { [weak self] in
            self?.panel?.orderOut(nil)
        }
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

        // 단축키 설정: 별도 패널로 분리하여 신뢰성 확보
        let shortcutItem = NSMenuItem(
            title: "단축키 설정...",
            action: #selector(showShortcutSettings),
            keyEquivalent: ","
        )
        shortcutItem.target = self
        menu.addItem(shortcutItem)

        menu.addItem(NSMenuItem.separator())

        let loginItem = NSMenuItem(
            title: "로그인 시 자동 실행",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        loginItem.tag = MenuItemTag.launchAtLogin
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
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
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
        panel?.isReleasedWhenClosed = false
        // false: 다른 앱 포커스 시 패널 자동 숨김 방지
        panel?.hidesOnDeactivate = false
        panel?.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    private func setupKeyboardShortcut() {
        // AppDelegate는 앱 수명 동안 해제되지 않으므로 strong capture가 안전하다.
        KeyboardShortcuts.onKeyUp(for: .toggleEditor) { [self] in
            Task { @MainActor in
                self.togglePanel()
            }
        }
    }

    // MARK: - 액션

    @MainActor @objc private func statusButtonClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        guard event.type == .rightMouseUp else {
            // 좌클릭: 에디터 패널 토글
            togglePanel()
            return
        }

        // 우클릭: 설정 메뉴 표시
        syncLoginItemState()
        statusItem?.menu = settingsMenu
        statusItem?.button?.performClick(nil)
        // 메뉴 표시 후 즉시 제거해야 다음 좌클릭이 action을 다시 트리거함
        statusItem?.menu = nil
    }

    @MainActor @objc private func toggleLaunchAtLogin() {
        appState.launchAtLogin.toggle()
        syncLoginItemState()
    }

    @objc private func showShortcutSettings() {
        // 최초 호출 시 패널을 한 번만 생성하고 이후에는 재사용한다.
        if shortcutSettingsPanel == nil {
            let contentView = NSHostingView(rootView: ShortcutSettingsView())
            contentView.layout()

            let sPanel = NSPanel(
                contentRect: NSRect(origin: .zero, size: contentView.fittingSize),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            sPanel.title = "단축키 설정"
            sPanel.contentView = contentView
            sPanel.isReleasedWhenClosed = false
            shortcutSettingsPanel = sPanel
        }
        shortcutSettingsPanel?.center()
        shortcutSettingsPanel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Private

    private func togglePanel() {
        if panel?.isVisible == true {
            panel?.orderOut(nil)
        } else {
            positionPanelBelowStatusItem()
            panel?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    /// 패널을 메뉴바 아이콘 바로 아래에 배치한다.
    ///
    /// 화면 오른쪽 경계를 벗어나지 않도록 x 좌표를 보정한다.
    private func positionPanelBelowStatusItem() {
        guard let panel = panel,
              let button = statusItem?.button,
              let buttonWindow = button.window else { return }

        let buttonFrameInScreen = buttonWindow.convertToScreen(button.frame)
        let panelSize = panel.frame.size

        // 버튼 중앙 기준으로 패널 x 위치 결정, 메뉴바 바로 아래에 배치
        var x = buttonFrameInScreen.midX - panelSize.width / 2
        let y = buttonFrameInScreen.minY - panelSize.height

        // 화면 경계 보정
        if let screenFrame = NSScreen.main?.visibleFrame {
            x = min(x, screenFrame.maxX - panelSize.width)
            x = max(x, screenFrame.minX)
        }

        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    /// 설정 메뉴의 "로그인 시 자동 실행" 체크 상태를 실제 등록 상태와 동기화한다.
    @MainActor private func syncLoginItemState() {
        settingsMenu?.item(withTag: MenuItemTag.launchAtLogin)?
            .state = appState.launchAtLogin ? .on : .off
    }
}
