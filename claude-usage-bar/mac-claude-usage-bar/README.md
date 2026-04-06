# Claude UsageBar

macOS 메뉴바에서 **Claude Pro / Max 사용량**을 실시간으로 확인하는 네이티브 앱.

- **별도 로그인 불필요** — Claude Code CLI의 Keychain 토큰을 자동으로 사용
- **공식 OAuth API** — 화면 스크래핑 없이 공식 인증 경로로만 데이터 취득
- **경량 네이티브** — SwiftUI + URLSession, Electron/WebView 불필요

> **전제 조건**: Claude Code CLI(`claude` 명령)가 설치되어 있고 로그인된 상태여야 합니다.

---

## 기능

| 항목                           | 설명                                              |
| ------------------------------ | ------------------------------------------------- |
| **Current session**            | 5시간 롤링 윈도우 사용률 (%) + 리셋 시각          |
| **Current week (all models)**  | 7일 전체 모델 사용률                              |
| **Current week (Sonnet only)** | 7일 Sonnet 전용 사용률                            |
| **Claude Code (today)**        | OTel 활성화 시 — 오늘의 토큰 수, 비용($), 세션 수 |
| **Launch at login**            | 로그인 시 자동 실행 토글                          |

메뉴바에는 현재 세션 사용률이 상시 표시됩니다 (예: `⊙ 42%`).

---

## 요구 사항

- macOS 14 (Sonoma) 이상
- [Claude Code CLI](https://claude.ai/code) 설치 및 로그인 완료

---

## 설치

```bash
git clone https://github.com/cyb9701/ClaudeUsageBar.git
cd ClaudeUsageBar
make install
```

빌드 후 `~/Applications/ClaudeUsageBar.app`이 자동 생성되고 즉시 실행됩니다.

> **Keychain 팝업이 반복될 경우**: `make setup-keychain`을 한 번 실행하세요.  
> `"Claude Code-credentials"` 항목에 TeamID ACL을 등록하여 이후 팝업을 영구 차단합니다.  
> 실행 시 macOS 로그인 비밀번호를 한 번 입력해야 합니다.

---

## Claude Code OTel 메트릭 (선택)

오늘 사용한 토큰 수·비용·세션 수를 메뉴바에 표시하려면 Claude Code CLI에서 아래 환경 변수를 설정하세요.

```bash
export CLAUDE_CODE_ENABLE_TELEMETRY=1
export OTEL_METRICS_EXPORTER=prometheus
```

설정 후 Claude Code를 재시작하면 **Claude Code (today)** 섹션이 자동으로 나타납니다.

---

## 업데이트

```bash
git pull
make update
```

## 삭제

```bash
make uninstall
```

---

## 라이선스

MIT License
