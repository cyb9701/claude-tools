# 클립보드 히스토리 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 복사 버튼 클릭 및 에디터 내 Cmd+C 시 기록을 저장하고, 타이틀바 🕐 버튼으로 패널 우측에 히스토리를 표시하는 기능 추가

**Architecture:** `ClipboardHistory`를 별도 라이브러리 타겟(`ClipboardHistoryKit`)으로 분리하여 단위 테스트를 가능하게 한다. UI는 `EditorView` 안에서 HStack으로 에디터(400px)와 히스토리 패널(160px)을 나란히 배치하며, NSPanel 너비를 AppDelegate가 동적으로 제어한다. `onToggleHistory` 콜백으로 SwiftUI → AppDelegate 간 리사이즈를 조율한다.

**Tech Stack:** SwiftUI, AppKit(NSPanel, NSEvent, NSPasteboard), Swift Observation(`@Observable`), XCTest

---

## 파일 구조

```
ClipboardHistoryKit/
└── ClipboardHistory.swift          # 신규: 순수 히스토리 로직 라이브러리

Tests/
└── ClipboardHistoryTests.swift     # 신규: 단위 테스트

Sources/
├── Core/
│   └── AppState.swift              # 수정: history, showingHistory, onToggleHistory 추가
├── Features/
│   ├── Editor/
│   │   └── EditorView.swift        # 수정: 🕐 버튼 + HStack 레이아웃
│   └── History/
│       └── HistoryPanelView.swift  # 신규: 히스토리 목록 뷰
└── ClaudeMDEditorApp.swift         # 수정: onToggleHistory 콜백, NSEvent 모니터, 리사이즈
```

---

## Task 1: Package.swift 업데이트 및 ClipboardHistoryKit 골격 생성

**Files:**
- Modify: `Package.swift`
- Create: `ClipboardHistoryKit/ClipboardHistory.swift`

- [ ] **Step 1: Package.swift를 다음으로 교체**

```swift
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
```

- [ ] **Step 2: ClipboardHistoryKit/ 디렉토리 생성 및 골격 파일 작성**

```bash
mkdir -p ClipboardHistoryKit
```

`ClipboardHistoryKit/ClipboardHistory.swift` 내용:

```swift
import Foundation
import Observation

@MainActor
@Observable
public final class ClipboardHistory {
    public private(set) var items: [String] = []
    private let maxCount = 10

    public init() {}

    public func add(_ text: String) {
        // TODO: 구현 예정 (Task 3에서)
    }
}
```

- [ ] **Step 3: Tests/ 디렉토리 생성**

```bash
mkdir -p Tests
```

- [ ] **Step 4: 빌드 확인**

```bash
swift build
```

예상 결과: `Build complete!` (ClipboardHistory.add는 아직 비어 있어도 컴파일 성공)

---

## Task 2: ClipboardHistory 단위 테스트 작성 (TDD — 실패 먼저)

**Files:**
- Create: `Tests/ClipboardHistoryTests.swift`

- [ ] **Step 1: 테스트 파일 작성**

`Tests/ClipboardHistoryTests.swift`:

```swift
import XCTest
@testable import ClipboardHistoryKit

@MainActor
final class ClipboardHistoryTests: XCTestCase {

    func test_add_appendsItem() {
        let history = ClipboardHistory()
        history.add("hello")
        XCTAssertEqual(history.items, ["hello"])
    }

    func test_add_prependsNewest() {
        let history = ClipboardHistory()
        history.add("first")
        history.add("second")
        XCTAssertEqual(history.items, ["second", "first"])
    }

    func test_add_trimsToMaxCount() {
        let history = ClipboardHistory()
        for i in 1...11 {
            history.add("item \(i)")
        }
        XCTAssertEqual(history.items.count, 10)
        XCTAssertEqual(history.items.first, "item 11")
        XCTAssertFalse(history.items.contains("item 1"))
    }

    func test_add_deduplicatesAndMovesToFront() {
        let history = ClipboardHistory()
        history.add("hello")
        history.add("world")
        history.add("hello")
        XCTAssertEqual(history.items, ["hello", "world"])
    }

    func test_add_ignoresEmptyString() {
        let history = ClipboardHistory()
        history.add("")
        history.add("   ")
        XCTAssertTrue(history.items.isEmpty)
    }
}
```

- [ ] **Step 2: 테스트 실행 — 실패 확인**

```bash
swift test
```

예상 결과: 5개 테스트 모두 FAIL (`add`가 빈 구현이므로)

---

## Task 3: ClipboardHistory 구현 (테스트 통과)

**Files:**
- Modify: `ClipboardHistoryKit/ClipboardHistory.swift`

- [ ] **Step 1: add() 구현**

`ClipboardHistoryKit/ClipboardHistory.swift` 전체 교체:

```swift
import Foundation
import Observation

/// 복사 기록 저장소.
///
/// 최대 10개를 메모리에 유지하며, 중복 항목은 제거 후 최신으로 재등록한다.
/// 앱 종료 시 초기화된다.
@MainActor
@Observable
public final class ClipboardHistory {

    /// 최신순으로 정렬된 복사 기록 목록.
    public private(set) var items: [String] = []

    private let maxCount = 10

    public init() {}

    /// 텍스트를 기록에 추가한다.
    ///
    /// 공백만 있는 텍스트는 무시하고, 동일 텍스트가 이미 있으면 기존 항목을 제거한 뒤
    /// 맨 앞에 삽입한다. 최대 개수 초과 시 가장 오래된 항목을 제거한다.
    public func add(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        items.removeAll { $0 == text }
        items.insert(text, at: 0)
        if items.count > maxCount {
            items.removeLast()
        }
    }
}
```

- [ ] **Step 2: 테스트 실행 — 통과 확인**

```bash
swift test
```

예상 결과:
```
Test Suite 'ClaudePromptPadTests' passed.
Executed 5 tests, with 0 failures
```

- [ ] **Step 3: 커밋**

```bash
git add ClipboardHistoryKit/ClipboardHistory.swift Tests/ClipboardHistoryTests.swift Package.swift Package.resolved
git commit -m "feat: add ClipboardHistory with unit tests"
```

---

## Task 4: AppState 업데이트

**Files:**
- Modify: `Sources/Core/AppState.swift`

- [ ] **Step 1: AppState.swift 전체 교체**

```swift
import Foundation
import Observation
import ServiceManagement
import SwiftUI
import ClipboardHistoryKit

/// 에디터 앱 전역 상태.
///
/// @AppStorage로 텍스트를 유지하여 앱 재시작 후에도 마지막 내용을 복원한다.
/// launchAtLogin은 SMAppService 실제 등록 상태와 항상 동기화된다.
@MainActor
@Observable
final class AppState {

    /// UserDefaults 키 상수.
    ///
    /// 문자열 중복을 방지하고 오타로 인한 저장 불일치를 막는다.
    private enum Keys {
        static let editorText = "editorText"
    }

    /// 에디터 텍스트.
    ///
    /// UserDefaults에 직접 저장하여 @Observable 추적을 유지한다.
    /// @ObservationIgnored + @AppStorage 조합은 programmatic 변경 시 UI 갱신이 누락되므로 didSet 방식으로 대체한다.
    var text: String = UserDefaults.standard.string(forKey: Keys.editorText) ?? "" {
        didSet { UserDefaults.standard.set(text, forKey: Keys.editorText) }
    }

    /// 복사 완료 상태.
    ///
    /// 패널이 열릴 때 AppDelegate에서 false로 리셋하여 버튼이 초기 상태로 돌아오도록 한다.
    var isCopied = false

    /// 히스토리 패널 표시 여부.
    ///
    /// true일 때 NSPanel 너비가 560px으로 확장되고 EditorView 우측에 HistoryPanelView가 나타난다.
    /// AppDelegate의 onToggleHistory 콜백이 패널 리사이즈를 담당하므로 직접 수정하지 않는다.
    var showingHistory = false

    /// 복사 기록 저장소.
    ///
    /// 메모리 only — 앱 종료 시 초기화된다.
    let history = ClipboardHistory()

    /// 패널 닫기 콜백.
    ///
    /// AppDelegate에서 주입하며, 복사 완료 시 EditorView에서 호출하여 패널을 즉시 닫는다.
    @ObservationIgnored
    var onClosePanel: (() -> Void)?

    /// 히스토리 토글 콜백.
    ///
    /// AppDelegate에서 주입하며, 🕐 버튼 클릭 시 NSPanel 리사이즈 후 showingHistory를 변경한다.
    /// SwiftUI에서 직접 showingHistory를 수정하면 패널 리사이즈보다 UI 갱신이 먼저 일어나므로
    /// AppDelegate가 순서를 제어한다.
    @ObservationIgnored
    var onToggleHistory: (() -> Void)?

    /// 로그인 시 자동 실행 여부.
    ///
    /// SMAppService 실제 등록 상태를 읽고 쓴다.
    /// .app 번들로 설치된 상태에서만 정상 동작한다.
    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                // 번들 외부(swift run, make run 등) 실행 시 실패 — 무시
            }
        }
    }
}
```

- [ ] **Step 2: 빌드 확인**

```bash
swift build
```

예상 결과: `Build complete!`

- [ ] **Step 3: 커밋**

```bash
git add Sources/Core/AppState.swift
git commit -m "feat: add history and showingHistory to AppState"
```

---

## Task 5: HistoryPanelView 구현

**Files:**
- Create: `Sources/Features/History/HistoryPanelView.swift`

- [ ] **Step 1: 디렉토리 및 파일 생성**

```bash
mkdir -p Sources/Features/History
```

`Sources/Features/History/HistoryPanelView.swift`:

```swift
import SwiftUI
import AppKit

/// 복사 기록 목록 뷰.
///
/// EditorView 우측에 배치되며, 항목 클릭 시 해당 텍스트를 클립보드에 복사하고 패널을 닫는다.
/// 기록이 없을 때는 안내 문구를 표시한다.
struct HistoryPanelView: View {

    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 0) {
            // 헤더: 에디터 타이틀바와 동일한 .bar 소재로 시각적 통일성 확보
            HStack {
                Text("복사 기록")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(.bar)

            Divider()

            if appState.history.items.isEmpty {
                // 빈 상태 안내
                Spacer()
                Text("아직 복사 기록이\n없습니다")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Spacer()
            } else {
                // 히스토리 목록
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(appState.history.items, id: \.self) { item in
                            historyItemButton(text: item)
                        }
                    }
                    .padding(6)
                }
            }
        }
        .background(.background)
    }

    /// 히스토리 항목 버튼.
    ///
    /// 클릭 시 클립보드에 복사하고 onClosePanel을 통해 패널을 즉시 닫는다.
    private func historyItemButton(text: String) -> some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            appState.onClosePanel?()
        } label: {
            Text(text)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 2: 빌드 확인**

```bash
swift build
```

예상 결과: `Build complete!`

- [ ] **Step 3: 커밋**

```bash
git add Sources/Features/History/HistoryPanelView.swift
git commit -m "feat: add HistoryPanelView"
```

---

## Task 6: EditorView 업데이트

**Files:**
- Modify: `Sources/Features/Editor/EditorView.swift`

- [ ] **Step 1: EditorView.swift 전체 교체**

```swift
import SwiftUI
import AppKit

/// 에디터 메인 뷰.
///
/// 에디터(400px 고정)와 히스토리 패널(showingHistory 시 우측에 표시)을 HStack으로 구성한다.
/// 패널 너비 변경은 AppDelegate의 onToggleHistory 콜백이 담당한다.
struct EditorView: View {

    @Environment(AppState.self) private var appState

    /// 현재 텍스트의 줄 수.
    private var lineCount: Int {
        appState.text.isEmpty ? 0 : appState.text.components(separatedBy: "\n").count
    }

    /// 현재 텍스트의 글자 수 (공백 포함).
    private var charCount: Int {
        appState.text.count
    }

    var body: some View {
        @Bindable var appState = appState

        HStack(spacing: 0) {
            // 에디터 영역 (400×300 고정)
            VStack(spacing: 0) {
                // 상단 타이틀바: macOS .bar 소재를 사용해 시스템 배경과 자연스럽게 통합
                HStack {
                    Text("Claude PromptPad")
                        .font(.headline)
                    Spacer()
                    Text("\(lineCount)줄 · \(charCount)자")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()

                    // 히스토리 토글 버튼: AppDelegate의 onToggleHistory를 통해 패널 리사이즈와 함께 처리
                    Button {
                        appState.onToggleHistory?()
                    } label: {
                        Image(systemName: "clock")
                            .foregroundStyle(appState.showingHistory ? Color.accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.bar)

                Divider()

                // 텍스트 에디터 영역 (flex): 시스템 기본 배경과 폰트 사용
                TextEditor(text: $appState.text)
                    .font(.system(.body, design: .monospaced))

                Divider()

                // 하단 버튼 바: macOS .bar 소재로 타이틀바와 대칭 구성
                HStack(spacing: 8) {
                    // 초기화 버튼 (왼쪽, bordered 스타일로 secondary 액션 표현)
                    Button("초기화") {
                        appState.text = ""
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    // 클립보드 복사 버튼 (전체 너비).
                    // 복사 후 히스토리에 저장하고 "복사됨!" 피드백을 0.6초 보여준 뒤 패널을 닫는다.
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(appState.text, forType: .string)
                        appState.history.add(appState.text)
                        appState.isCopied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            appState.onClosePanel?()
                        }
                    } label: {
                        Text(appState.isCopied ? "복사됨!" : "클립보드에 복사")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(appState.isCopied)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(.bar)
            }
            .frame(width: 400, height: 300)

            // 히스토리 패널: showingHistory가 true일 때만 표시, 너비는 NSPanel이 제어
            if appState.showingHistory {
                Divider()
                HistoryPanelView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
```

- [ ] **Step 2: 빌드 확인**

```bash
swift build
```

예상 결과: `Build complete!`

- [ ] **Step 3: 커밋**

```bash
git add Sources/Features/Editor/EditorView.swift
git commit -m "feat: add clock button and history panel layout to EditorView"
```

---

## Task 7: AppDelegate 업데이트

**Files:**
- Modify: `Sources/ClaudeMDEditorApp.swift`

패널 너비 상수:
- 에디터 전용: `400`px
- 히스토리 포함: `560`px (= 400 에디터 + 1 구분선 + 159 히스토리)
- 높이: `300`px (불변)

- [ ] **Step 1: ClaudeMDEditorApp.swift 전체 교체**

```swift
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
```

- [ ] **Step 2: 빌드 확인**

```bash
swift build
```

예상 결과: `Build complete!`

- [ ] **Step 3: 커밋**

```bash
git add Sources/ClaudeMDEditorApp.swift
git commit -m "feat: implement history panel toggle and Cmd+C monitoring in AppDelegate"
```

---

## Task 8: 수동 테스트 체크리스트

- [ ] **Step 1: 앱 실행**

```bash
make run
# 또는
swift run
```

- [ ] **Step 2: 기능 검증**

| 시나리오 | 예상 결과 |
|---------|---------|
| "클립보드에 복사" 버튼 클릭 | 텍스트가 클립보드에 복사되고 패널이 닫힘 |
| 패널 재오픈 → 🕐 클릭 | 히스토리 패널이 우측에 나타남, 패널 너비 560px |
| 히스토리 목록에 방금 복사한 항목 표시 확인 | 최신 항목이 맨 위에 표시됨 |
| 히스토리 항목 클릭 | 해당 텍스트 클립보드 복사 + 패널 닫힘 |
| 🕐 재클릭 | 히스토리 패널 닫힘, 패널 너비 400px 복원 |
| 에디터에서 텍스트 입력 후 Cmd+A → Cmd+C | 히스토리에 저장됨 (🕐로 확인) |
| 동일 텍스트 두 번 복사 | 히스토리에 중복 없이 1개만 유지, 최신으로 이동 |
| 10개 초과 복사 | 가장 오래된 항목이 자동 제거, 10개 유지 |
| ESC 키 (히스토리 열린 상태) | 히스토리만 닫힘, 메인 패널 유지 |
| 패널 닫기 후 재오픈 | 히스토리 닫힌 상태로 열림 (400px) |
| 기록 없을 때 🕐 클릭 | "아직 복사 기록이 없습니다" 문구 표시 |

- [ ] **Step 3: 최종 커밋**

```bash
git add .
git commit -m "feat: clipboard history — select from previous copies via clock button"
```
