import SwiftUI

/// 메뉴바 팝오버 메인 뷰.
///
/// Pro 5시간 윈도우, 주간 캡, 모델별 한도, Claude Code OTel 메트릭을 표시한다.
/// macOS 26+에서는 각 섹션이 Liquid Glass 카드로 렌더링된다.
struct MenuBarView: View {

    @Environment(AppState.self) private var state
    // 리셋 카운트다운 실시간 업데이트를 위한 타이머
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var tickCount = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerCard
            proUsageCard
            if state.isOTelAvailable, let metrics = state.codeMetrics {
                codeMetricsCard(metrics)
            }
            footerCard
        }
        .padding(12)
        .frame(width: 290)
        .onReceive(ticker) { _ in tickCount += 1 } // 뷰 재계산 트리거
    }

    // MARK: - 헤더 카드

    private var headerCard: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(state.statusColor)
                .frame(width: 8, height: 8)
            Text("Claude 사용량")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            if state.isLoading {
                ProgressView().scaleEffect(0.65)
            } else {
                Button {
                    Task { await state.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("지금 갱신")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .glassCard()
    }

    // MARK: - Pro 사용량 카드

    private var proUsageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let window = state.fiveHourUsage {
                usageRow(label: "5시간 윈도우", icon: "clock.fill", window: window)
            }
            if let window = state.sevenDayUsage {
                usageRow(label: "7일 캡", icon: "calendar", window: window)
            }
            if let window = state.sevenDaySonnetUsage {
                usageRow(label: "7일 Sonnet", icon: "sparkles", window: window)
            }
            if state.fiveHourUsage == nil && !state.isLoading {
                errorView
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .glassCard()
    }

    // MARK: - 사용량 행 (ProgressBar + 리셋 시각)

    private func usageRow(label: String, icon: String, window: RateWindow) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label(label, systemImage: icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(window.percentInt)%")
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundStyle(progressColor(for: window.ratio))
            }

            ProgressView(value: window.ratio)
                .tint(progressColor(for: window.ratio))
                .frame(height: 6)
                .scaleEffect(x: 1, y: 1.2, anchor: .center)

            if let subtitle = resetLabel(for: window) {
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Claude Code OTel 메트릭 카드

    private func codeMetricsCard(_ m: CodeUsageMetrics) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Claude Code (오늘)", systemImage: "terminal")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                chip(value: formatTokens(m.inputTokens + m.outputTokens), label: "토큰")
                chip(value: String(format: "$%.3f", m.costUSD), label: "비용")
                chip(value: "\(Int(m.sessionCount))", label: "세션")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .glassCard()
    }

    private func chip(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .glassChip()
    }

    // MARK: - 에러 뷰

    private var errorView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("데이터 로드 실패", systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.orange)

            if let msg = state.errorMessage {
                Text(msg)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("Claude Code를 먼저 실행하고 로그인해주세요.")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(8)
        .glassCard(cornerRadius: 8)
        // 에러 상태임을 명시하기 위해 orange 테두리 오버레이
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.orange.opacity(0.4), lineWidth: 0.5)
        )
    }

    // MARK: - 푸터 카드

    private var footerCard: some View {
        @Bindable var state = state
        return VStack(spacing: 6) {
            // 로그인 시 자동 실행 토글
            Toggle(isOn: $state.launchAtLogin) {
                Label("로그인 시 자동 실행", systemImage: "power")
                    .font(.system(size: 11))
            }
            .toggleStyle(.switch)
            .controlSize(.mini)

            HStack {
                if let updated = state.lastUpdated {
                    Text(relativeTime(from: updated))
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                } else {
                    Text("로딩 중...")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Button("종료") { NSApplication.shared.terminate(nil) }
                    .font(.system(size: 10))
                    .buttonStyle(.plain)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .glassCard()
    }

    // MARK: - 헬퍼

    private func progressColor(for ratio: Double) -> Color {
        switch ratio {
        case ..<0.5: return .green
        case ..<0.8: return .yellow
        default: return .red
        }
    }

    private func resetLabel(for window: RateWindow) -> String? {
        guard let seconds = window.secondsUntilReset else { return nil }
        if seconds <= 0 { return "리셋됨" }
        let h = Int(seconds) / 3600
        let m = Int(seconds) % 3600 / 60
        let s = Int(seconds) % 60
        if h > 0 { return "리셋까지 \(h)시간 \(m)분" }
        if m > 0 { return "리셋까지 \(m)분 \(s)초" }
        return "리셋까지 \(s)초"
    }

    private func relativeTime(from date: Date) -> String {
        let diff = Int(-date.timeIntervalSinceNow)
        if diff < 60 { return "방금 갱신" }
        if diff < 3600 { return "\(diff / 60)분 전 갱신" }
        return "\(diff / 3600)시간 전 갱신"
    }

    private func formatTokens(_ tokens: Double) -> String {
        switch tokens {
        case 1_000_000...: return String(format: "%.1fM", tokens / 1_000_000)
        case 1_000...: return String(format: "%.1fK", tokens / 1_000)
        default: return "\(Int(tokens))"
        }
    }
}

// MARK: - 메뉴바 라벨 뷰

/// 메뉴바에 상시 표시되는 아이콘 + 사용률.
///
/// 커스텀 상태바 아이콘(icon_status_bar.png)을 사용하며,
/// 리소스 로드 실패 시 SF Symbol 폴백으로 동작한다.
struct MenuBarLabelView: View {

    let appState: AppState

    var body: some View {
        HStack(spacing: 3) {
            statusBarIcon
            Text(appState.shortStatusText)
                .font(.system(size: 11, weight: .medium).monospacedDigit())
        }
    }

    /// 번들 리소스에서 상태바 아이콘을 로드하여 표시한다.
    @ViewBuilder
    private var statusBarIcon: some View {
        if let url = Bundle.module.url(forResource: "icon_status_bar", withExtension: "png"),
           let nsImage = NSImage(contentsOf: url) {
            Image(nsImage: nsImage)
                .resizable()
                .frame(width: 18, height: 18)
        } else {
            // 리소스 로드 실패 시 폴백
            Image(systemName: "circle.fill")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(appState.statusColor)
        }
    }
}
