import Foundation

/// Claude Pro OAuth 사용량 조회기.
///
/// api.anthropic.com/api/oauth/usage 엔드포인트를 호출한다.
/// anthropic-beta: oauth-2025-04-20 헤더가 필수이며,
/// CodexBar 오픈소스 분석에서 확인된 엔드포인트이다.
///
/// 실제 응답 구조:
/// { "five_hour": { "utilization": 50.0, "resets_at": "..." },
///   "seven_day": { "utilization": 45.0, "resets_at": "..." }, ... }
final class OAuthUsageFetcher: UsageFetching, @unchecked Sendable {

    private let tokenManager = OAuthTokenManager.shared
    private let session: URLSession

    private static let usageURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    private static let betaHeaderValue = "oauth-2025-04-20"

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        session = URLSession(configuration: config)
    }

    // MARK: - 공개 메서드

    /// Pro 사용량 데이터 조회.
    func fetchUsage() async throws -> ClaudeUsageData {
        let token = try await tokenManager.getValidToken()

        var request = URLRequest(url: Self.usageURL)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(Self.betaHeaderValue, forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeUsageError.apiError(0, "HTTP 응답 없음")
        }

        guard httpResponse.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8) ?? "알 수 없는 오류"
            throw ClaudeUsageError.apiError(httpResponse.statusCode, message)
        }

        return try parseResponse(data)
    }

    // MARK: - 응답 파싱

    private func parseResponse(_ data: Data) throws -> ClaudeUsageData {
        let decoded = try JSONDecoder().decode(OAuthUsageAPIResponse.self, from: data)

        guard let result = decoded.toUsageData() else {
            let raw = String(data: data, encoding: .utf8) ?? "(디코딩 불가)"
            throw ClaudeUsageError.unexpectedResponseFormat(raw)
        }

        return result
    }
}
