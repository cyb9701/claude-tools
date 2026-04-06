import Foundation
import Security

/// OAuth 토큰 관리자.
///
/// macOS Keychain의 "Claude Code-credentials" 항목에서 토큰을 로드한다.
/// 실제 Keychain JSON 구조:
/// {
///   "claudeAiOauth": {
///     "accessToken": "sk-ant-oat01-...",
///     "refreshToken": "sk-ant-ort01-...",
///     "expiresAt": 1774950761041,  // 밀리초 단위 Unix 타임스탬프
///     "scopes": [...],
///     "subscriptionType": "max",
///     "rateLimitTier": "..."
///   },
///   "organizationUuid": "..."
/// }
/// actor를 사용하여 Swift 6의 데이터 레이스 안전성을 보장한다.
actor OAuthTokenManager {

    static let shared = OAuthTokenManager()

    // 메모리 캐시: 만료 60초 전까지 유효
    private var cachedToken: String?
    private var tokenExpiresAt: Date?
    private var cachedRefreshToken: String?

    private init() {}

    // MARK: - 공개 메서드

    /// 유효한 access token 반환. 만료 시 자동 갱신.
    ///
    /// Keychain 접근 빈도를 최소화하여 비밀번호 팝업을 줄인다.
    /// 캐시 → refresh token으로 HTTP 갱신 → Keychain 순서로 시도한다.
    func getValidToken() async throws -> String {
        // 1단계: 캐시된 토큰이 아직 유효하면 즉시 반환
        if let cached = cachedToken,
           let expiresAt = tokenExpiresAt,
           expiresAt.timeIntervalSinceNow > 60 {
            return cached
        }

        // 2단계: 캐시된 refresh token으로 HTTP 갱신 시도 (Keychain 접근 없음)
        if let refreshToken = cachedRefreshToken, !refreshToken.isEmpty {
            if let newToken = try? await refreshAccessToken(using: refreshToken) {
                return newToken
            }
        }

        // 3단계: Keychain에서 자격증명 로드 (팝업 발생 가능)
        let credentials = try loadFromKeychain()

        // HTTP 갱신 전에 refresh token을 먼저 캐시한다.
        // 갱신이 실패하더라도 이후 Stage 2에서 재시도할 수 있다.
        if !credentials.refreshToken.isEmpty {
            cachedRefreshToken = credentials.refreshToken
        }

        // 토큰 만료 여부 확인 후 갱신
        if let expiresAt = credentials.expiresAt,
           expiresAt.timeIntervalSinceNow < 60,
           !credentials.refreshToken.isEmpty {
            return try await refreshAccessToken(using: credentials.refreshToken)
        }

        // 유효한 토큰 캐시 저장
        cachedToken = credentials.accessToken
        tokenExpiresAt = credentials.expiresAt

        return credentials.accessToken
    }

    // MARK: - Keychain 읽기

    private func loadFromKeychain() throws -> OAuthCredentials {
        // 1순위: "Claude Code-credentials" (Claude Code CLI)
        if let credentials = try? readKeychain(
            service: "Claude Code-credentials",
            account: NSUserName()
        ) {
            return credentials
        }

        // 2순위: 환경변수 (DEBUG 빌드 전용 테스트 폴백).
        // 릴리즈 빌드에서는 환경변수를 통한 토큰 우회를 차단하여
        // 의도치 않은 토큰 노출을 방지한다.
        #if DEBUG
        if let envToken = ProcessInfo.processInfo.environment["CLAUDE_OAUTH_TOKEN"] {
            return OAuthCredentials(
                accessToken: envToken,
                refreshToken: "",
                expiresAt: Date().addingTimeInterval(3600)
            )
        }
        #endif

        throw ClaudeUsageError.credentialsNotFound
    }

    private func readKeychain(service: String, account: String) throws -> OAuthCredentials {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess, let data = item as? Data else {
            throw ClaudeUsageError.keychainReadFailed(status)
        }

        return try parseCredentialsData(data)
    }

    private func parseCredentialsData(_ data: Data) throws -> OAuthCredentials {
        // 래퍼 구조 파싱: { "claudeAiOauth": { "accessToken": ... } }
        if let wrapper = try? JSONDecoder().decode(CredentialsWrapper.self, from: data) {
            return wrapper.claudeAiOauth
        }

        // 래퍼 없는 직접 구조: { "accessToken": ... }
        if let direct = try? JSONDecoder().decode(OAuthCredentials.self, from: data) {
            return direct
        }

        // 단순 토큰 문자열
        if let tokenString = String(data: data, encoding: .utf8),
           tokenString.hasPrefix("sk-ant-") {
            return OAuthCredentials(
                accessToken: tokenString.trimmingCharacters(in: .whitespacesAndNewlines),
                refreshToken: "",
                expiresAt: nil
            )
        }

        throw ClaudeUsageError.invalidCredentials
    }

    // MARK: - 토큰 갱신

    private func refreshAccessToken(using refreshToken: String) async throws -> String {
        var request = URLRequest(
            url: URL(string: "https://platform.claude.com/v1/oauth/token")!,
            timeoutInterval: 30
        )
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        // URLComponents를 사용하여 refresh token의 특수문자(+, =, & 등)를
        // 안전하게 퍼센트 인코딩한다.
        var bodyComponents = URLComponents()
        bodyComponents.queryItems = [
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "refresh_token", value: refreshToken),
        ]
        request.httpBody = bodyComponents.percentEncodedQuery?.data(using: .utf8)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            // 네트워크 계층 오류 (연결 없음, 타임아웃 등) — 재시도 가능
            throw ClaudeUsageError.tokenRefreshNetworkError
        }

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            // HTTP 4xx/5xx: 인증 오류 (토큰 무효, 서버 오류 등) — 재로그인 필요
            throw ClaudeUsageError.tokenRefreshFailed
        }

        let refreshed = try JSONDecoder().decode(TokenRefreshResponse.self, from: data)

        cachedToken = refreshed.accessToken
        tokenExpiresAt = Date().addingTimeInterval(TimeInterval(refreshed.expiresIn ?? 3600))
        // 서버가 새 refresh token을 반환한 경우(토큰 로테이션) 캐시를 갱신한다.
        if let newRefreshToken = refreshed.refreshToken, !newRefreshToken.isEmpty {
            cachedRefreshToken = newRefreshToken
        }
        return refreshed.accessToken
    }
}

// MARK: - 내부 모델

/// Keychain 최상위 래퍼 구조.
private struct CredentialsWrapper: Decodable {
    let claudeAiOauth: OAuthCredentials
}

/// OAuth 자격증명. expiresAt은 밀리초 단위 Unix 타임스탬프.
struct OAuthCredentials: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date?

    init(accessToken: String, refreshToken: String, expiresAt: Date?) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
    }

    private enum CodingKeys: String, CodingKey {
        case accessToken, refreshToken, expiresAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        guard let token = try? c.decode(String.self, forKey: .accessToken) else {
            throw ClaudeUsageError.invalidCredentials
        }
        accessToken = token
        refreshToken = (try? c.decode(String.self, forKey: .refreshToken)) ?? ""

        // expiresAt: 밀리초 단위 Unix 타임스탬프 (예: 1774950761041)
        if let ms = try? c.decode(Double.self, forKey: .expiresAt) {
            // 2001-09-09 이후의 타임스탬프(13자리 이상)는 밀리초 단위로 판별한다.
            // 초 단위(10자리)와 밀리초 단위(13자리)를 구분하는 경계값.
            let millisecondsThreshold: Double = 1_000_000_000_000
            let seconds = ms > millisecondsThreshold ? ms / 1000 : ms
            expiresAt = Date(timeIntervalSince1970: seconds)
        } else if let isoStr = try? c.decode(String.self, forKey: .expiresAt) {
            expiresAt = ISO8601DateFormatter().date(from: isoStr)
        } else {
            expiresAt = nil
        }
    }
}

/// 토큰 갱신 API 응답.
///
/// OAuth 2.0 RFC 6749 §6에 따라 서버는 새 refresh token을 반환할 수 있다(토큰 로테이션).
/// refreshToken이 nil이면 기존 캐시된 refresh token을 계속 사용한다.
struct TokenRefreshResponse: Decodable {
    let accessToken: String
    let expiresIn: Int?
    /// 서버가 토큰 로테이션 시 반환하는 새 refresh token.
    let refreshToken: String?

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
    }
}
