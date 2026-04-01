import SwiftUI
import Observation
import ServiceManagement

/// 앱 전역 상태 관리자.
///
/// @Observable을 사용하여 SwiftUI 뷰와 자동으로 동기화된다.
/// 5분 주기로 Pro 사용량을 갱신하고, 1분 주기로 OTel 메트릭을 갱신한다.
@Observable
final class AppState {

    // MARK: - 공개 상태

    var fiveHourUsage: RateWindow?
    var sevenDayUsage: RateWindow?
    var sevenDaySonnetUsage: RateWindow?
    var codeMetrics: CodeUsageMetrics?
    var lastUpdated: Date?
    var errorMessage: String?
    var isLoading = false
    var isOTelAvailable = false

    /// 로그인 시 자동 실행 여부.
    ///
    /// SMAppService를 통해 시스템 로그인 항목을 등록/해제한다.
    /// .app 번들로 실행 중일 때만 정상 동작한다.
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
                // 번들 외부(swift run 등)에서 실행 시 실패 — 무시
            }
        }
    }

    // MARK: - 의존성

    private let usageFetcher = OAuthUsageFetcher()
    private let prometheusPoller = PrometheusPoller()

    // MARK: - 타이머

    private var refreshTimer: Timer?
    private var otelTimer: Timer?

    // MARK: - 초기화

    init() {
        startTimers()
        // 앱 시작 직후 Keychain 접근이 불안정할 수 있으므로
        // 짧은 지연 후 첫 조회를 수행하고, 실패 시 한 번 재시도한다.
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            await refresh()
            await pollOTel()
            // 첫 조회 실패 시 3초 후 재시도
            if fiveHourUsage == nil {
                try? await Task.sleep(for: .seconds(3))
                await refresh()
            }
        }
    }

    // MARK: - 공개 메서드

    /// 사용량 데이터 수동 갱신.
    func refresh() async {
        await MainActor.run { isLoading = true }

        do {
            let data = try await usageFetcher.fetchUsage()
            await MainActor.run {
                fiveHourUsage = data.fiveHour
                sevenDayUsage = data.sevenDay
                sevenDaySonnetUsage = data.sevenDaySonnet
                lastUpdated = data.fetchedAt
                errorMessage = nil
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    // MARK: - Private

    private func pollOTel() async {
        let metrics = await prometheusPoller.poll()
        await MainActor.run {
            codeMetrics = metrics
            isOTelAvailable = metrics != nil
        }
    }

    private func startTimers() {
        // Pro 사용량: 5분 주기
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { await self?.refresh() }
        }

        // OTel 메트릭: 1분 주기
        otelTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { await self?.pollOTel() }
        }
    }
}

// MARK: - 편의 계산 속성

extension AppState {

    /// 메뉴바 아이콘 색상 (5시간 윈도우 사용률 기반).
    var statusColor: Color {
        guard let ratio = fiveHourUsage?.ratio else { return .gray }
        switch ratio {
        case ..<0.5: return .green
        case ..<0.8: return .yellow
        default: return .red
        }
    }

    /// 메뉴바에 표시할 짧은 사용률 문자열.
    var shortStatusText: String {
        guard let usage = fiveHourUsage else { return "?" }
        return "\(usage.percentInt)%"
    }
}
