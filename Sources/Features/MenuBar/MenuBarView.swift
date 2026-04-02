import SwiftUI

/// 메뉴바 팝오버 메인 뷰.
///
/// Pro 사용량(Current session, Current week), Claude Code OTel 메트릭을 표시한다.
/// macOS 네이티브 메뉴바 팝오버 스타일을 따른다.
struct MenuBarView: View {

    @Environment(AppState.self) private var state
    // 리셋 카운트다운 실시간 업데이트를 위한 타이머
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var tickCount = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
            Divider().padding(.horizontal, 12)
            proUsageSection
            if state.isOTelAvailable, let metrics = state.codeMetrics {
                Divider().padding(.horizontal, 12)
                codeMetricsSection(metrics)
            }
            Divider().padding(.horizontal, 12)
            footerSection
        }
        .padding(.vertical, 6)
        .frame(width: 300)
        .onReceive(ticker) { _ in tickCount += 1 }
    }

    // MARK: - 헤더

    private var headerSection: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(state.statusColor)
                .frame(width: 8, height: 8)
            Text("Claude Usage")
                .font(.system(size: 14, weight: .semibold))
            Spacer()
            if state.isLoading {
                ProgressView().scaleEffect(0.65)
            } else {
                Button {
                    Task { await state.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Refresh now")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Pro 사용량

    private var proUsageSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let window = state.fiveHourUsage {
                usageRow(label: "Current session", icon: "clock.fill", window: window)
            }
            if let window = state.sevenDayUsage {
                usageRow(label: "Current week (all models)", icon: "calendar", window: window)
            }
            if let window = state.sevenDaySonnetUsage {
                usageRow(label: "Current week (Sonnet only)", icon: "sparkles", window: window)
            }
            if state.fiveHourUsage == nil && !state.isLoading {
                errorView
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - 사용량 행 (ProgressBar + 리셋 시각)

    private func usageRow(label: String, icon: String, window: RateWindow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(label, systemImage: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(window.percentInt)%")
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(progressColor(for: window.ratio))
            }

            ProgressView(value: window.ratio)
                .tint(progressColor(for: window.ratio))
                .frame(height: 6)
                .scaleEffect(x: 1, y: 1.2, anchor: .center)

            if let subtitle = resetLabel(for: window) {
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Claude Code OTel 메트릭

    private func codeMetricsSection(_ m: CodeUsageMetrics) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Claude Code (today)", systemImage: "terminal")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                chip(value: formatTokens(m.inputTokens + m.outputTokens), label: "tokens")
                chip(value: String(format: "$%.3f", m.costUSD), label: "cost")
                chip(value: "\(Int(m.sessionCount))", label: "sessions")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func chip(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 7))
    }

    // MARK: - 에러 뷰

    private var errorView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Failed to load data", systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.orange)

            if let msg = state.errorMessage {
                Text(msg)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // 네트워크 오류 시에는 로그인 안내가 부적절하므로 표시하지 않는다.
            if !(state.errorMessage?.contains("네트워크") ?? false) {
                Text("Please run Claude Code and sign in first.")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        // 에러 상태임을 명시하기 위해 orange 테두리 오버레이
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.orange.opacity(0.4), lineWidth: 0.5)
        )
    }

    // MARK: - 푸터

    private var footerSection: some View {
        @Bindable var state = state
        // tickCount를 읽어 1초마다 뷰 재평가를 강제한다.
        let _ = tickCount
        return VStack(spacing: 8) {
            Toggle(isOn: $state.launchAtLogin) {
                Label("Launch at login", systemImage: "power")
                    .font(.system(size: 12))
            }
            .toggleStyle(.switch)
            .controlSize(.mini)

            HStack {
                if let updated = state.lastUpdated {
                    Text(relativeTime(from: updated))
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                } else {
                    Text("Loading...")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .font(.system(size: 11))
                    .buttonStyle(.plain)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - 헬퍼

    private func progressColor(for ratio: Double) -> Color {
        switch ratio {
        case ..<0.5: return .green
        case ..<0.8: return .yellow
        default: return .red
        }
    }

    /// 리셋 시각을 Asia/Seoul 타임존의 절대시간으로 표시한다.
    ///
    /// 오늘이면 "Resets 2pm (Asia/Seoul)", 내일 이후이면 "Resets Apr 4 at 11pm (Asia/Seoul)".
    private func resetLabel(for window: RateWindow) -> String? {
        guard let resetAt = window.resetAt else { return nil }
        guard let seconds = window.secondsUntilReset, seconds > 0 else { return "Reset" }

        let seoul = TimeZone(identifier: "Asia/Seoul")!
        let now = Date()

        let formatter = DateFormatter()
        formatter.timeZone = seoul
        formatter.locale = Locale(identifier: "en_US_POSIX")

        // Seoul 타임존 기준으로 오늘인지 판별
        var seoulCalendar = Calendar.current
        seoulCalendar.timeZone = seoul
        let isToday = seoulCalendar.isDate(resetAt, inSameDayAs: now)
        let isTomorrow = seoulCalendar.isDateInTomorrow(resetAt)

        formatter.dateFormat = "ha"
        let timeStr = formatter.string(from: resetAt).lowercased()

        if isToday || isTomorrow {
            return "Resets \(timeStr) (Asia/Seoul)"
        } else {
            let dayFormatter = DateFormatter()
            dayFormatter.timeZone = seoul
            dayFormatter.locale = Locale(identifier: "en_US_POSIX")
            dayFormatter.dateFormat = "MMM d"
            let dayStr = dayFormatter.string(from: resetAt)
            return "Resets \(dayStr) at \(timeStr) (Asia/Seoul)"
        }
    }

    /// 마지막 갱신 시각의 상대 시간 표시.
    private func relativeTime(from date: Date) -> String {
        let diff = Int(Date().timeIntervalSince(date))
        if diff < 60 { return "Updated just now" }
        if diff < 3600 { return "Updated \(diff / 60)m ago" }
        return "Updated \(diff / 3600)h ago"
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
        HStack(alignment: .center, spacing: 3) {
            statusBarIcon
            Text(appState.shortStatusText)
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                // 메뉴바 텍스트 수직 정렬 기준을 명시적으로 설정
                .baselineOffset(0)
        }
    }

    /// 번들 리소스에서 상태바 아이콘을 로드하여 표시한다.
    ///
    /// macOS 메뉴바 권장 아이콘 크기는 16×16pt.
    /// .renderingMode(.template)으로 다크/라이트 모드 자동 대응.
    @ViewBuilder
    private var statusBarIcon: some View {
        if let url = Bundle.module.url(forResource: "icon_status_bar", withExtension: "png"),
           let nsImage = NSImage(contentsOf: url) {
            Image(nsImage: nsImage)
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .frame(width: 16, height: 16)
        } else {
            // 리소스 로드 실패 시 폴백
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(appState.statusColor)
        }
    }
}
