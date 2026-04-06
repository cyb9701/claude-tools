# 클립보드 히스토리 기능 설계

**날짜:** 2026-04-06  
**프로젝트:** claude-prompt-pad  
**상태:** 승인됨

---

## 개요

"클립보드에 복사" 버튼 클릭 또는 에디터에서 Cmd+C 사용 시 복사 기록을 자동 저장하고, 타이틀바의 🕐 버튼으로 이전 기록을 조회·재사용할 수 있는 기능을 추가한다.

---

## 요구사항

| 항목 | 내용 |
|------|------|
| 저장 시점 | ① "클립보드에 복사" 버튼 클릭, ② 에디터에서 Cmd+C |
| 최대 개수 | 10개 (초과 시 가장 오래된 항목 제거) |
| 영속성 | 메모리 only (앱 종료 시 초기화) |
| 중복 처리 | 동일 텍스트는 기존 항목 제거 후 최신으로 재등록 |
| 항목 클릭 동작 | 해당 텍스트를 클립보드에 복사 + 패널 닫힘 |

---

## UI 설계

### 레이아웃

- 타이틀바 우측에 🕐 버튼 추가 (줄/글자 수 옆)
- 🕐 클릭 시 히스토리 패널이 **현재 패널 우측**에 붙어서 나타남
- 현재 패널(에디터)은 위치·크기 변화 없음
- 패널 너비: 400px → 560px (히스토리 영역 160px 추가)
- 패널 높이: 300px 유지

### 인터랙션 규칙

- 히스토리 항목 클릭 → 클립보드 복사 + 패널 닫힘 + 히스토리 닫힘
- ESC 키 → 히스토리 패널만 닫힘 (메인 패널 유지)
- 🕐 버튼 재클릭 → 토글 (닫힘)
- 항목이 없을 때 → "아직 복사 기록이 없습니다" 안내 문구
- 메인 패널이 닫힐 때 → `showingHistory` 리셋

### 너비 확장 위치 조정

`showingHistory` 토글 시 `positionPanelBelowStatusItem()`을 재호출하여 너비 변경 후 메뉴바 아이콘 기준 위치를 재조정한다.

---

## 아키텍처

### 신규 파일

#### `Sources/Core/ClipboardHistory.swift`

```swift
@Observable final class ClipboardHistory {
    private(set) var items: [String] = []
    private let maxCount = 10

    func add(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        items.removeAll { $0 == text }   // 중복 제거
        items.insert(text, at: 0)        // 최신순 prepend
        if items.count > maxCount {
            items.removeLast()
        }
    }
}
```

#### `Sources/Features/History/HistoryPanelView.swift`

- 히스토리 목록을 렌더링하는 SwiftUI 뷰
- 항목 클릭 시 클립보드 복사 + `onClosePanel` 호출

### 수정 파일

#### `Sources/Core/AppState.swift`

추가 프로퍼티:
```swift
let history = ClipboardHistory()
var showingHistory = false
```

#### `Sources/Features/Editor/EditorView.swift`

- 타이틀바에 🕐 버튼 추가 (`showingHistory` 토글)
- `HStack`으로 에디터 뷰와 `HistoryPanelView`를 나란히 배치
- `showingHistory`가 true일 때만 `HistoryPanelView` 표시

#### `Sources/ClaudeMDEditorApp.swift` (AppDelegate)

- `setupPanel()` 내에서 NSEvent 로컬 모니터 등록
- Cmd+C 감지 시 현재 `appState.text`를 `appState.history.add()`로 저장
- 패널이 닫힐 때 `appState.showingHistory = false` 리셋

---

## Cmd+C 감지 방식

```swift
NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
    if event.modifierFlags.contains(.command),
       event.charactersIgnoringModifiers == "c" {
        self.appState.history.add(self.appState.text)
    }
    return event  // 이벤트 소비하지 않고 그대로 전달
}
```

- `return event`로 이벤트를 소비하지 않아 실제 복사 동작은 정상 처리됨
- 패널이 열려 있는 동안만 동작 (NSPanel의 로컬 모니터 범위)

---

## 파일 구조

```
Sources/
├── Core/
│   ├── AppState.swift              # 수정
│   └── ClipboardHistory.swift      # 신규
├── Features/
│   ├── Editor/
│   │   └── EditorView.swift        # 수정
│   └── History/
│       └── HistoryPanelView.swift  # 신규
└── ClaudeMDEditorApp.swift         # 수정
```

---

## 미결 사항

없음.
