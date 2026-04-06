import SwiftUI
import Observation
import ServiceManagement

// MARK: - 의존성 프로토콜

/// Pro 사용량 조회 추상화.
///
/// 테스트 시 Mock 주입이 가능하도록 프로토콜로 분리한다.
protocol UsageFetching: Sendable {
    func fetchUsage() async throws -> ClaudeUsageData
}

/// OTel 메트릭 폴링 추상화.
///
/// 테스트 시 Mock 주입이 가능하도록 프로토콜로 분리한다.
protocol MetricsPolling: Sendable {
    func poll() async -> CodeUsageMetrics?
}

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
    /// 네트워크 오류 여부 (에러 뷰에서 로그인 안내 표시 판별용).
    var isNetworkError = false
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

    private let usageFetcher: UsageFetching
    private let metricsPoller: MetricsPolling

    // MARK: - 타이머

    private var refreshTimer: Timer?
    private var otelTimer: Timer?

    // MARK: - 초기화

    /// 의존성 주입을 통해 테스트 용이성을 확보한다.
    ///
    /// 프로덕션에서는 기본 구현체(OAuthUsageFetcher, PrometheusPoller)를 사용하고,
    /// 테스트에서는 Mock 객체를 주입할 수 있다.
    init(
        usageFetcher: UsageFetching = OAuthUsageFetcher(),
        metricsPoller: MetricsPolling = PrometheusPoller()
    ) {
        self.usageFetcher = usageFetcher
        self.metricsPoller = metricsPoller
        startTimers()
        Task { @MainActor in
            await performStartupRefreshWithBackoff()
        }
    }

    deinit {
        refreshTimer?.invalidate()
        otelTimer?.invalidate()
    }

    // MARK: - 상수

    /// 부팅 후 재시도 백오프 간격.
    ///
    /// WiFi 연결, FileVault 잠금 해제 등 macOS 부팅 환경의
    /// 지연을 고려하여 점진적으로 대기 시간을 늘린다.
    private static let startupBackoffDelays: [Duration] = [
        .seconds(2), .seconds(5), .seconds(15), .seconds(30)
    ]

    // MARK: - 공개 메서드

    /// 부팅 직후 지수적 백오프 초기 조회.
    ///
    /// macOS 부팅 환경(WiFi 지연, FileVault 잠금 해제 등)에서는
    /// Keychain과 네트워크가 준비되기까지 시간이 걸릴 수 있다.
    /// 1s 초기 대기 후 실패 시 startupBackoffDelays 순서로 최대 4회 재시도한다.
    private func performStartupRefreshWithBackoff() async {
        try? await Task.sleep(for: .seconds(1))
        await refresh()
        await pollOTel()
        guard fiveHourUsage == nil else { return }

        for delay in Self.startupBackoffDelays {
            try? await Task.sleep(for: delay)
            await refresh()
            if fiveHourUsage != nil { return }
        }
    }

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
                isNetworkError = false
                isLoading = false
            }
        } catch {
            let networkError: Bool
            if case ClaudeUsageError.tokenRefreshNetworkError = error {
                networkError = true
            } else {
                networkError = false
            }
            await MainActor.run {
                errorMessage = error.localizedDescription
                isNetworkError = networkError
                isLoading = false
            }
        }
    }

    // MARK: - Private

    private func pollOTel() async {
        let metrics = await metricsPoller.poll()
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
    ///
    /// 50% 미만: 여유 (green), 50~80%: 주의 (yellow), 80% 이상: 경고 (red).
    /// 사용자가 rate limit 도달 전에 사용량을 인지할 수 있도록
    /// 80%부터 빨간색으로 전환한다.
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
