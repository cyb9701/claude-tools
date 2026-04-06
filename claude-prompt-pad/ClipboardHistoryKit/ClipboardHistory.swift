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

    /// 히스토리에 저장 가능한 최대 항목 수.
    ///
    /// 이 값을 초과하면 가장 오래된 항목부터 제거된다.
    private let maxCount = 10

    public init() {}

    /// 텍스트를 기록에 추가한다.
    ///
    /// 공백만 있는 텍스트는 무시하고, 동일 텍스트가 이미 있으면 기존 항목을 제거한 뒤
    /// 맨 앞에 삽입한다. 최대 개수 초과 시 가장 오래된 항목을 제거한다.
    public func add(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        // 원본 텍스트 기준 중복 제거 — 클립보드 내용은 정확한 문자열로 관리한다.
        items.removeAll { $0 == text }
        items.insert(text, at: 0)
        if items.count > maxCount {
            items.removeLast()
        }
    }
}
