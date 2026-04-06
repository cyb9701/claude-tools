import SwiftUI
import AppKit

/// 에디터 메인 뷰.
///
/// 상단 타이틀바(제목 + 줄/글자 수), 중앙 TextEditor, 하단 버튼 바(초기화 + 복사)로 구성된다.
/// 복사 버튼 클릭 시 NSPasteboard에 텍스트를 쓰고 1초간 "✓ 복사됨" 피드백을 표시한다.
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

        VStack(spacing: 0) {
            // 상단 타이틀바
            HStack {
                Text("Claude MD Editor")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(lineCount)줄 · \(charCount)자")
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // 텍스트 에디터 영역 (flex)
            TextEditor(text: $appState.text)
                .font(.system(size: 13, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)

            Divider()

            // 하단 버튼 바
            HStack(spacing: 8) {
                // 초기화 버튼 (소형, 왼쪽)
                Button("초기화") {
                    appState.text = ""
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                // 클립보드 복사 버튼 (전체 너비)
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(appState.text, forType: .string)
                    appState.copySuccess = true
                    Task {
                        try? await Task.sleep(for: .seconds(1))
                        appState.copySuccess = false
                    }
                } label: {
                    Text(appState.copySuccess ? "✓ 복사됨" : "클립보드에 복사")
                        .frame(maxWidth: .infinity)
                        .frame(height: 22)
                }
                .buttonStyle(.borderedProminent)
                .animation(.easeInOut(duration: 0.2), value: appState.copySuccess)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .frame(width: 600, height: 400)
    }
}
