# Claude PromptPad

🌐 **English** | [한국어](README.ko.md)

> Write AI prompts from the macOS menu bar — one shortcut away, no focus switching required.

[![macOS](https://img.shields.io/badge/macOS-14%2B-blue?logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange?logo=swift&logoColor=white)](https://swift.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](../LICENSE)

<!-- Screenshot: Floating panel below menu bar icon showing prompt editor with line/char count -->

![Popup](screenshots/screenshot-popup.png)

## Why

Typing prompts directly in the terminal has three recurring pain points:

- **Line breaks** — pressing Return submits the prompt before you're done
- **File paths** — attaching paths inline is awkward and error-prone
- **Korean input** — characters often corrupt or display incorrectly in terminal input

Claude PromptPad solves this by giving you a proper editor in the menu bar. Write the full prompt with line breaks and file paths, then paste it into the terminal in one shot.

## Features

- **Global shortcut** — open the panel from any app without switching focus
- **Floating panel** — always on top, stays visible while you work in other apps
- **Auto-close on copy** — copies to clipboard and dismisses the panel instantly
- **Persistent text** — restores your last prompt after app restarts
- **Customizable shortcut** — bind any key combination from the right-click menu

## What's Displayed

| Element | Description |
| ------- | ----------- |
| **Editor** | Monospaced text area for writing prompts |
| **Line count** | Live line count shown in the title bar |
| **Char count** | Live character count shown in the title bar |
| **Reset** | Clears the editor in one click |
| **Copy to Clipboard** | Copies text and closes the panel automatically |

## Requirements

- macOS 14 (Sonoma) or later
- No external accounts or logins required

## Installation

```bash
git clone https://github.com/cyb9701/claude-tools.git
cd claude-tools/claude-prompt-pad
make install
```

Builds the app and installs it to `~/Applications/Claude PromptPad.app`.

## Shortcut Configuration

Right-click the menu bar icon → **단축키 설정...** to bind a custom global shortcut.

<!-- Screenshot: Shortcut recorder panel -->

![Shortcuts](screenshots/screenshot-shortcuts.png)

## Update & Uninstall

```bash
# Update (run from the repo root)
git pull
cd claude-prompt-pad
make update

# Uninstall (run from claude-prompt-pad/)
make uninstall
```

## License

MIT
