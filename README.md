# ClaudeUsageBar

macOS 메뉴바에서 **Claude Pro / Max 사용량**을 실시간으로 확인하는 네이티브 앱.

```
메뉴바: ● 50%

팝오버:
┌──────────────────────────────┐
│ ● Claude 사용량          ↻   │
├──────────────────────────────┤
│ 🕐 5시간 윈도우          50% │
│ ██████████░░░░░░░░░░         │
│ 리셋까지 2시간 14분          │
│                              │
│ 📅 7일 캡                45% │
│ █████████░░░░░░░░░░░         │
│ 리셋까지 3일 14시간          │
│                              │
│ ✦  7일 Sonnet            12% │
│ ██░░░░░░░░░░░░░░░░░░         │
├──────────────────────────────┤
│ > Claude Code (오늘)         │
│ [  42.3K  ] [ $0.042 ] [ 8 ] │
│   토큰        비용      세션  │
├──────────────────────────────┤
│ 방금 갱신                종료 │
└──────────────────────────────┘
```

## 특징

- **별도 로그인 불필요** — Claude Code CLI 설치 시 생성된 Keychain 토큰을 자동으로 사용
- **공식 OAuth API 사용** — `api.anthropic.com/api/oauth/usage` 엔드포인트 (CodexBar 오픈소스에서 확인)
- **ToS 준수** — 화면 스크래핑 없이 공식 인증 경로로만 데이터 취득
- **경량 네이티브 앱** — SwiftUI + URLSession, Electron/WebView 불필요
- **OTel 지원** — Claude Code CLI의 Prometheus 메트릭도 선택적으로 표시

---

## 요구 사항

| 항목 | 버전 |
|------|------|
| macOS | 14 (Sonoma) 이상 |
| Xcode | 15 이상 |
| Swift | 5.9 이상 |
| Claude Code CLI | 최신 버전 (로그인 완료 상태) |

> **중요:** Claude Code CLI(`claude` 명령)가 설치되어 있고 **로그인된 상태**여야 합니다.  
> 앱은 Claude Code가 macOS Keychain에 저장한 OAuth 토큰을 읽어 사용합니다.

---

## 설치 및 실행

### 1단계 — 저장소 클론

```bash
git clone https://github.com/yourname/ClaudeUsageBar.git
cd ClaudeUsageBar
```

### 2단계 — 설치 (최초 1회)

```bash
make install
```

빌드 후 `~/Applications/ClaudeUsageBar.app`을 자동 생성하고 즉시 실행합니다.  
메뉴바에 `● ?%` 아이콘이 나타나면 설치 성공입니다.

### 이후 실행

Xcode 불필요합니다. Finder나 Spotlight에서 **ClaudeUsageBar**를 검색하거나:

```bash
open ~/Applications/ClaudeUsageBar.app
```

### 로그인 시 자동 실행 설정

**시스템 설정 → 일반 → 로그인 항목 및 확장 프로그램 → ClaudeUsageBar 추가**

### 업데이트 (코드 변경 후)

```bash
make update   # 재빌드 후 실행 중인 앱 자동 교체
```

### 삭제

```bash
make uninstall
```

### Makefile 전체 명령어

| 명령어 | 설명 |
|--------|------|
| `make install` | 빌드 + `~/Applications` 설치 + 실행 (최초 1회) |
| `make update` | 재빌드 + 실행 중인 앱 교체 |
| `make run` | 빌드 + 터미널에서 직접 실행 (개발용) |
| `make uninstall` | 설치된 앱 삭제 |
| `make clean` | 빌드 캐시 삭제 |

---

## Claude Code CLI 설치 및 로그인 확인

ClaudeUsageBar는 Claude Code CLI의 Keychain 토큰을 사용합니다.

```bash
# Claude Code 설치 여부 확인
which claude

# 로그인 상태 확인 (아래 명령이 성공하면 OK)
security find-generic-password -s "Claude Code-credentials" -a "$(whoami)" -w > /dev/null && echo "로그인됨"

# 미로그인 시 로그인
claude login
```

---

## OTel 설정 (선택 — Claude Code 메트릭 표시)

`~/.zshrc` 또는 `~/.bash_profile`에 추가하면 팝오버 하단에 **오늘의 토큰/비용/세션** 정보가 표시됩니다.

```bash
export CLAUDE_CODE_ENABLE_TELEMETRY=1
export OTEL_METRICS_EXPORTER=prometheus
# → localhost:9464/metrics 에 Prometheus HTTP 서버 자동 기동
```

설정 후 새 터미널에서 `claude` 명령을 실행하면 ClaudeUsageBar가 자동으로 메트릭을 수집합니다.

검증:

```bash
# Prometheus 서버가 기동 중인지 확인
curl -s http://localhost:9464/metrics | grep claude_code_cost
```

---

## 동작 원리

### 인증 흐름

```
앱 시작
  └─ macOS Keychain 읽기
       "Claude Code-credentials" (계정: 사용자명)
       ↓ JSON 구조
       { "claudeAiOauth": {
           "accessToken": "sk-ant-oat01-...",
           "refreshToken": "sk-ant-ort01-...",
           "expiresAt": 1774950761041   ← 밀리초 단위
         }
       }
       ↓ 토큰 만료 시
       POST https://platform.claude.com/v1/oauth/token
```

### 사용량 API

```http
GET https://api.anthropic.com/api/oauth/usage
Authorization: Bearer sk-ant-oat01-...
anthropic-beta: oauth-2025-04-20

응답:
{
  "five_hour":     { "utilization": 50.0, "resets_at": "2026-03-31T05:00:01Z" },
  "seven_day":     { "utilization": 45.0, "resets_at": "2026-04-04T14:00:00Z" },
  "seven_day_sonnet": { "utilization": 12.0, "resets_at": "..." },
  ...
}
```

### 갱신 주기

| 데이터 | 주기 |
|--------|------|
| Pro 사용량 (5시간/주간) | 5분 |
| OTel Prometheus 메트릭 | 1분 |
| 리셋 카운트다운 | 1초 (로컬 타이머) |

---

## 프로젝트 구조

```
ClaudeUsageBar/
├── Package.swift
├── README.md
└── Sources/
    ├── ClaudeUsageBarApp.swift              # @main 진입점, MenuBarExtra 설정
    ├── Core/
    │   ├── UsageModel.swift            # 도메인 모델 + API 응답 디코딩
    │   └── AppState.swift              # @Observable 전역 상태, 타이머 관리
    ├── Auth/
    │   └── OAuthTokenManager.swift     # Keychain 읽기, 토큰 갱신 (actor)
    └── Features/
        ├── MenuBar/
        │   └── MenuBarView.swift       # 팝오버 UI + 메뉴바 라벨 뷰
        ├── ProUsage/
        │   └── OAuthUsageFetcher.swift # OAuth Usage API 호출
        └── OTel/
            └── PrometheusPoller.swift  # localhost:9464/metrics 폴링
```

---

## 문제 해결

### "데이터 로드 실패" 오류

```bash
# 1. Claude Code 로그인 확인
claude login

# 2. Keychain 항목 직접 확인
security find-generic-password \
  -s "Claude Code-credentials" \
  -a "$(whoami)" -w 2>/dev/null | python3 -c "
import sys, json
d = json.loads(sys.stdin.read())
token = d.get('claudeAiOauth', {}).get('accessToken', '없음')
print('토큰:', token[:30], '...')
"

# 3. API 직접 테스트
TOKEN=$(security find-generic-password -s "Claude Code-credentials" -a "$(whoami)" -w | \
  python3 -c "import sys,json; print(json.loads(sys.stdin.read())['claudeAiOauth']['accessToken'])")

curl -s \
  -H "Authorization: Bearer $TOKEN" \
  -H "anthropic-beta: oauth-2025-04-20" \
  https://api.anthropic.com/api/oauth/usage | python3 -m json.tool
```

### OTel 메트릭이 표시되지 않음

```bash
# Claude Code를 OTel 활성화 상태로 실행했는지 확인
echo $CLAUDE_CODE_ENABLE_TELEMETRY   # "1" 이어야 함
echo $OTEL_METRICS_EXPORTER          # "prometheus" 이어야 함

# Prometheus 서버 응답 확인
curl -s http://localhost:9464/metrics | head -20
```

---

## 참고 및 감사

- [CodexBar](https://github.com/steipete/CodexBar) — OAuth 엔드포인트 및 Keychain 구조 분석의 참고 오픈소스
- [Claude Code 공식 OTel 문서](https://code.claude.com/docs) — Prometheus 메트릭 설정 참고

---

## 라이선스

MIT License
