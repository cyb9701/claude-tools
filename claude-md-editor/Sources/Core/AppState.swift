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

    /// 에디터 텍스트.
    ///
    /// @AppStorage를 통해 UserDefaults에 자동 저장된다.
    /// @ObservationIgnored로 표시하여 @Observable 추적 충돌을 방지한다.
    @ObservationIgnored
    @AppStorage("editorText") var text: String = ""

    /// 복사 완료 후 버튼 피드백을 1초간 표시하기 위한 상태.
    var copySuccess: Bool = false

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
