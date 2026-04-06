import Foundation

/// OTel Prometheus 메트릭 폴러.
///
/// Claude Code에 CLAUDE_CODE_ENABLE_TELEMETRY=1, OTEL_METRICS_EXPORTER=prometheus를
/// 설정하면 localhost:9464/metrics 에 HTTP 서버가 자동 기동된다.
/// 이 클래스는 해당 엔드포인트를 폴링하여 Claude Code CLI 사용 메트릭을 수집한다.
///
/// 모든 프로퍼티가 let(불변)이므로 @unchecked Sendable이 안전하다.
/// URLSession은 내부적으로 스레드 안전한 구현이므로 동시 접근에 문제없다.
final class PrometheusPoller: MetricsPolling, @unchecked Sendable {

    private let metricsURL = URL(string: "http://localhost:9464/metrics")!

    /// URLSession을 재사용하여 1분 주기 폴링 시 세션 생성 비용을 절감한다.
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 3 // Claude Code 미실행 시 빠른 실패
        return URLSession(configuration: config)
    }()

    // MARK: - 공개 메서드

    /// 메트릭 폴링. Prometheus 서버 미실행 시 nil 반환.
    func poll() async -> CodeUsageMetrics? {
        guard let text = await fetchMetricsText() else { return nil }
        return parsePrometheusText(text)
    }

    // MARK: - Private

    private func fetchMetricsText() async -> String? {
        do {
            let (data, response) = try await session.data(from: metricsURL)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            return String(data: data, encoding: .utf8)
        } catch {
            // 연결 실패는 정상 상태 (Claude Code 미실행) — 에러 로그 생략
            return nil
        }
    }

    /// Prometheus 텍스트 포맷 파싱.
    ///
    /// Prometheus 텍스트 형식 예시:
    /// # HELP claude_code_token_usage_total ...
    /// # TYPE claude_code_token_usage_total counter
    /// claude_code_token_usage_total{type="input",...} 42300.0
    private func parsePrometheusText(_ text: String) -> CodeUsageMetrics? {
        var inputTokens = 0.0
        var outputTokens = 0.0
        var cacheReadTokens = 0.0
        var costUSD = 0.0
        var sessionCount = 0.0

        for line in text.components(separatedBy: .newlines) {
            // 주석 및 빈 줄 스킵
            guard !line.hasPrefix("#"), !line.isEmpty else { continue }

            let value = extractValue(from: line)

            if line.contains("claude_code_token_usage") {
                if line.contains("type=\"input\"") {
                    inputTokens += value
                } else if line.contains("type=\"output\"") {
                    outputTokens += value
                } else if line.contains("type=\"cacheRead\"") {
                    cacheReadTokens += value
                }
            } else if line.contains("claude_code_cost_usage") {
                costUSD += value
            } else if line.contains("claude_code_session_count") {
                sessionCount += value
            }
        }

        // 모든 메트릭이 0이면 유의미한 데이터 없음
        guard inputTokens + outputTokens + costUSD + sessionCount > 0 else { return nil }

        return CodeUsageMetrics(
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cacheReadTokens: cacheReadTokens,
            costUSD: costUSD,
            sessionCount: sessionCount
        )
    }

    /// Prometheus 메트릭 줄에서 숫자 값 추출.
    ///
    /// 형식: "metric_name{labels} value [timestamp]"
    /// 라벨 값에 공백이 포함될 수 있으므로(Prometheus 스펙 허용),
    /// 중괄호 라벨 부분을 먼저 제거한 후 공백으로 분리하여 값을 추출한다.
    private func extractValue(from line: String) -> Double {
        // 중괄호 라벨 부분을 제거하여 "metric_name value [timestamp]" 형태로 정규화
        let stripped: String
        if let braceStart = line.firstIndex(of: "{"),
           let braceEnd = line.firstIndex(of: "}") {
            stripped = String(line[line.startIndex..<braceStart])
                + String(line[line.index(after: braceEnd)...])
        } else {
            stripped = line
        }
        let parts = stripped.components(separatedBy: " ").filter { !$0.isEmpty }
        // 최소 "metric_name value" 2개 토큰 필요
        guard parts.count >= 2 else { return 0 }
        return Double(parts[1]) ?? 0
    }
}
