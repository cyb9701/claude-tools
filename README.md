# ClaudeUsageBar

macOS 메뉴바에서 **Claude Pro / Max 사용량**을 실시간으로 확인하는 네이티브 앱.

- **별도 로그인 불필요** — Claude Code CLI의 Keychain 토큰을 자동으로 사용
- **공식 OAuth API** — 화면 스크래핑 없이 공식 인증 경로로만 데이터 취득
- **경량 네이티브** — SwiftUI + URLSession, Electron/WebView 불필요

> **전제 조건**: Claude Code CLI(`claude` 명령)가 설치되어 있고 로그인된 상태여야 합니다.

---

## 설치

```bash
git clone https://github.com/cyb9701/ClaudeUsageBar.git
cd ClaudeUsageBar
make install
```

빌드 후 `~/Applications/ClaudeUsageBar.app`이 자동 생성되고 즉시 실행됩니다.

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
