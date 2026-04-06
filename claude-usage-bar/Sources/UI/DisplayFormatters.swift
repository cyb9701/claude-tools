import SwiftUI

/// 메뉴바 UI에서 사용하는 표시 포맷팅 유틸리티.
///
/// MenuBarView의 단일 책임 원칙(SRP)을 위해 포맷팅 로직을 분리한다.
/// 날짜, 토큰 수, 색상 등 표시용 변환을 담당한다.
enum DisplayFormatters {

    // MARK: - 상수

    private static let seoulTimeZone = TimeZone(identifier: "Asia/Seoul")!

    /// 리셋 시각의 시간(hour) 표시용 포맷터.
    ///
    /// DateFormatter 생성 비용이 높으므로 static으로 재사용한다.
    /// resetLabel이 1초 주기 뷰 갱신에서 호출될 수 있어 매번 생성하면 비효율적이다.
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeZone = seoulTimeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "ha"
        return formatter
    }()

    /// 리셋 시각의 날짜(월/일) 표시용 포맷터.
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeZone = seoulTimeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    // MARK: - 색상

    /// 사용률에 따른 프로그레스바 색상.
    ///
    /// 50% 미만: 여유 (green), 50~80%: 주의 (yellow), 80% 이상: 경고 (red).
    static func progressColor(for ratio: Double) -> Color {
        switch ratio {
        case ..<0.5: return .green
        case ..<0.8: return .yellow
        default: return .red
        }
    }

    // MARK: - 시간

    /// 리셋 시각을 Asia/Seoul 타임존의 절대시간으로 표시한다.
    ///
    /// 오늘이면 "Resets 2pm (Asia/Seoul)", 내일 이후이면 "Resets Apr 4 at 11pm (Asia/Seoul)".
    static func resetLabel(for window: RateWindow) -> String? {
        guard let resetAt = window.resetAt else { return nil }
        guard let seconds = window.secondsUntilReset, seconds > 0 else { return "Reset" }

        // Seoul 타임존 기준으로 오늘인지 판별
        var seoulCalendar = Calendar.current
        seoulCalendar.timeZone = seoulTimeZone
        let now = Date()
        let isToday = seoulCalendar.isDate(resetAt, inSameDayAs: now)
        let isTomorrow = seoulCalendar.isDateInTomorrow(resetAt)

        let timeStr = timeFormatter.string(from: resetAt).lowercased()

        if isToday || isTomorrow {
            return "Resets \(timeStr) (Asia/Seoul)"
        } else {
            let dayStr = dayFormatter.string(from: resetAt)
            return "Resets \(dayStr) at \(timeStr) (Asia/Seoul)"
        }
    }

    /// 마지막 갱신 시각의 상대 시간 표시.
    static func relativeTime(from date: Date) -> String {
        let diff = Int(Date().timeIntervalSince(date))
        if diff < 60 { return "Updated just now" }
        if diff < 3600 { return "Updated \(diff / 60)m ago" }
        return "Updated \(diff / 3600)h ago"
    }

    // MARK: - 토큰

    /// 토큰 수를 축약된 문자열로 포맷팅한다.
    ///
    /// 1,000,000 이상이면 "1.5M", 1,000 이상이면 "42.3K", 미만이면 정수.
    static func formatTokens(_ tokens: Double) -> String {
        switch tokens {
        case 1_000_000...: return String(format: "%.1fM", tokens / 1_000_000)
        case 1_000...: return String(format: "%.1fK", tokens / 1_000)
        default: return "\(Int(tokens))"
        }
    }
}
