import Foundation
import Observation
import ServiceManagement
import SwiftUI

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

    /// 패널 닫기 콜백.
    ///
    /// AppDelegate에서 주입하며, 복사 완료 시 EditorView에서 호출하여 패널을 즉시 닫는다.
    /// @Observable 추적 대상이 아니므로 @ObservationIgnored로 표시한다.
    @ObservationIgnored
    var onClosePanel: (() -> Void)?

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
