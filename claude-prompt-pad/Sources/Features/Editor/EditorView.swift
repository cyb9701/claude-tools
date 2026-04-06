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
            // 이 너비(400)는 AppDelegate의 PanelWidth.editor와 반드시 일치해야 한다.
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
