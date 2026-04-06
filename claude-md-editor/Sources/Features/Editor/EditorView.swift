import SwiftUI
import AppKit

/// 에디터 메인 뷰.
///
/// 상단 타이틀바(제목 + 줄/글자 수), 중앙 TextEditor, 하단 버튼 바(초기화 + 복사)로 구성된다.
/// 복사 버튼 클릭 시 NSPasteboard에 텍스트를 쓰고 패널을 즉시 닫는다.
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
            // 상단 타이틀바: macOS .bar 소재를 사용해 시스템 배경과 자연스럽게 통합
            HStack {
                Text("Claude MD Editor")
                    .font(.headline)
                Spacer()
                Text("\(lineCount)줄 · \(charCount)자")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
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

                // 클립보드 복사 버튼 (전체 너비).
                // 복사 완료 즉시 패널을 닫아 터미널로 바로 전환할 수 있도록 한다.
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(appState.text, forType: .string)
                    appState.onClosePanel?()
                } label: {
                    Text("클립보드에 복사")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.bar)
        }
        .frame(width: 400, height: 300)
    }
}
