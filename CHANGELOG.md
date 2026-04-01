# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- Popover background changed to native macOS menu bar style (removed per-section glass cards, using system dividers)
- UI labels switched to English: "Current session", "Current week (all models)", "Current week (Sonnet only)"
- Reset time now shows absolute time in Asia/Seoul timezone (e.g., "Resets 2pm (Asia/Seoul)")
- README.md simplified to essentials (description, install, update)

### Fixed
- "Updated just now" text no longer stuck — footer now properly re-renders every second via `tickCount` dependency
- App now auto-fetches usage data on launch with retry (1s delay + retry on failure)
- Reduced Keychain access frequency to mitigate repeated password prompt — cached refresh token is used for HTTP renewal before falling back to Keychain

## [0.2.0] - 2026-03-31

### Added
- Liquid Glass UI components for macOS 26+ (`LiquidGlassModifier.swift`)
- Custom status bar icon (`icon_status_bar.png`)
- Glass card and glass chip view modifiers with macOS 14-15 fallback

## [0.1.0] - 2026-03-31

### Added
- Initial release
- macOS menu bar app showing Claude Pro/Max usage in real-time
- OAuth token auto-loading from macOS Keychain (Claude Code CLI credentials)
- Auto token refresh via `platform.claude.com/v1/oauth/token`
- 5-hour session, 7-day cap, 7-day Sonnet usage windows
- Optional OTel Prometheus metrics display (tokens, cost, sessions)
- Launch at login support via `SMAppService`
- `make install` / `make update` / `make uninstall` build system

[Unreleased]: https://github.com/cyb9701/ClaudeUsageBar/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/cyb9701/ClaudeUsageBar/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/cyb9701/ClaudeUsageBar/releases/tag/v0.1.0
