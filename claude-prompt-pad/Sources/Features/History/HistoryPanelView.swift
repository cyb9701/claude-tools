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
