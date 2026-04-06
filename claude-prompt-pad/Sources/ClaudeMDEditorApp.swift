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
struct ClaudePromptPadApp: App {
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
    private var keyEventMonitor: Any?
    let appState = AppState()

    // 패널 너비 상수.
    //
    // 히스토리 패널이 닫혔을 때와 열렸을 때의 너비를 명시적으로 관리하여
    // 매직 넘버가 코드 곳곳에 퍼지는 것을 방지한다.
    private enum PanelWidth {
        static let editor: CGFloat = 400
        static let withHistory: CGFloat = 560
    }
    private let panelHeight: CGFloat = 300

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
        setupCallbacks()
        setupKeyEventMonitor()
    }

    // MARK: - 설정

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }

        button.image = NSImage(
            systemSymbolName: "text.page.fill",
            accessibilityDescription: "Claude PromptPad"
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
            contentRect: NSRect(x: 0, y: 0, width: PanelWidth.editor, height: panelHeight),
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

    /// onClosePanel과 onToggleHistory 콜백을 AppState에 주입한다.
    ///
    /// SwiftUI 뷰가 패널 제어를 AppDelegate에 위임하기 위한 경계.
    private func setupCallbacks() {
        appState.onClosePanel = { [weak self] in
            self?.panel?.orderOut(nil)
        }

        // onToggleHistory: NSPanel 리사이즈를 먼저 수행한 뒤 showingHistory를 변경한다.
        // SwiftUI 상태 변경 전에 패널 크기를 확보해야 레이아웃 글리치가 없다.
        appState.onToggleHistory = { [weak self] in
            guard let self else { return }
            let willShow = !self.appState.showingHistory
            self.resizePanel(showingHistory: willShow)
            self.appState.showingHistory = willShow
        }
    }

    /// NSEvent 로컬 모니터로 Cmd+C와 ESC를 감지한다.
    ///
    /// Cmd+C: 현재 에디터 텍스트를 히스토리에 추가 (이벤트는 소비하지 않아 실제 복사 동작 유지)
    /// ESC: 히스토리 패널이 열려 있을 때만 닫음 (이벤트 소비)
    private func setupKeyEventMonitor() {
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel?.isVisible == true else { return event }

            // ESC: 히스토리 패널 닫기
            if event.keyCode == 53 && self.appState.showingHistory {
                self.resizePanel(showingHistory: false)
                self.appState.showingHistory = false
                return nil  // ESC 이벤트 소비 (패널이 닫히는 것 방지)
            }

            // Cmd+C: 에디터 텍스트 히스토리 저장
            if event.modifierFlags.contains(.command),
               event.charactersIgnoringModifiers == "c" {
                self.appState.history.add(self.appState.text)
            }

            return event
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
            // 패널을 열기 전에 상태를 초기화한다.
            appState.isCopied = false
            appState.showingHistory = false
            resizePanel(showingHistory: false)
            panel?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    /// 히스토리 표시 여부에 따라 NSPanel 너비를 조정하고 위치를 재조정한다.
    ///
    /// 히스토리 패널은 에디터 우측으로 확장되므로, 위치 계산은 에디터 너비(400)를 기준으로 한다.
    private func resizePanel(showingHistory: Bool) {
        guard let panel else { return }
        let targetWidth = showingHistory ? PanelWidth.withHistory : PanelWidth.editor
        panel.setContentSize(NSSize(width: targetWidth, height: panelHeight))
        positionPanelBelowStatusItem()
    }

    /// 패널을 메뉴바 아이콘 바로 아래에 배치한다.
    ///
    /// 에디터 영역(400px) 기준으로 x 좌표를 계산하여 히스토리가 열려도
    /// 에디터가 아이콘 아래에 정렬되도록 한다.
    /// 화면 오른쪽 경계를 벗어나지 않도록 x 좌표를 보정한다.
    private func positionPanelBelowStatusItem() {
        guard let panel,
              let button = statusItem?.button,
              let buttonWindow = button.window else { return }

        let buttonFrameInScreen = buttonWindow.convertToScreen(button.frame)
        let panelSize = panel.frame.size

        // 에디터 영역(400px) 중앙을 기준으로 x 위치 결정, 메뉴바 바로 아래에 배치
        var x = buttonFrameInScreen.midX - PanelWidth.editor / 2
        let y = buttonFrameInScreen.minY - panelSize.height

        // 화면 경계 보정 (전체 패널 너비 기준)
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
