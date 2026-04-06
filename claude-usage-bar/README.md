# ClaudeUsageBar

🌐 **English** | [한국어](README.ko.md)

> Monitor your Claude Pro / Max usage directly from the macOS menu bar.

[![macOS](https://img.shields.io/badge/macOS-14%2B-blue?logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange?logo=swift&logoColor=white)](https://swift.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](../LICENSE)

<!-- Screenshot: 세션 사용량, 주간 통계, Claude Code 오늘 메트릭이 표시된 드롭다운 -->

![Screenshot](screenshots/screenshot.png)

## Features

- **No login required** — reuses Claude Code CLI's Keychain token automatically
- **Official OAuth API** — no screen scraping, official authentication only
- **Lightweight & native** — SwiftUI + URLSession, no Electron or WebView

## What's Displayed

| Metric                         | Description                                           |
| ------------------------------ | ----------------------------------------------------- |
| **Current session**            | Rolling 5-hour usage rate (%) + next reset time       |
| **Current week (all models)**  | 7-day usage across all models                         |
| **Current week (Sonnet only)** | 7-day Sonnet-specific usage                           |
| **Claude Code (today)**        | _(Optional)_ Token count, cost ($), and session count |

## Requirements

- macOS 14 (Sonoma) or later
- [Claude Code CLI](https://claude.ai/code) — installed and logged in

## Installation

```bash
git clone https://github.com/cyb9701/claude-tools.git
cd claude-tools/claude-usage-bar
make install
```

Builds the app and installs it to `~/Applications/ClaudeUsageBar.app`.

> **Keychain popup appearing repeatedly?**  
> Run `make setup-keychain` once to permanently grant access. Requires your macOS login password.

## Optional: Claude Code Usage Metrics

To enable the **Claude Code (today)** section, set these environment variables in Claude Code CLI:

```bash
export CLAUDE_CODE_ENABLE_TELEMETRY=1
export OTEL_METRICS_EXPORTER=prometheus
```

Restart Claude Code — the section will appear automatically.

## Update & Uninstall

```bash
# Update
git pull && make update

# Uninstall
make uninstall
```

## License

MIT
