# Claude PromptPad

🌐 [English](README.md) | **한국어**

> macOS 메뉴바에서 AI 프롬프트를 작성하세요 — 단축키 하나로, 앱 전환 없이.

[![macOS](https://img.shields.io/badge/macOS-14%2B-blue?logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange?logo=swift&logoColor=white)](https://swift.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](../LICENSE)

<!-- Screenshot: 메뉴바 아이콘 아래 줄 수·글자 수가 표시된 플로팅 프롬프트 에디터 -->

![팝업](screenshots/screenshot-popup.png)

## 만든 이유

터미널에서 직접 프롬프트를 입력할 때 반복적으로 마주치는 세 가지 문제가 있습니다:

- **줄바꿈** — Enter를 누르면 작성이 끝나지 않았어도 프롬프트가 바로 전송됨
- **파일 경로 첨부** — 경로를 인라인으로 붙이는 과정이 번거롭고 오류가 생기기 쉬움
- **한글 깨짐** — 터미널 입력 환경에서 한글이 깨지거나 오동작하는 경우가 발생함

Claude PromptPad는 메뉴바에 제대로 된 에디터를 제공해 이 문제를 해결합니다. 줄바꿈과 파일 경로를 자유롭게 작성한 뒤, 완성된 프롬프트를 터미널에 한 번에 붙여넣으세요.

## 주요 기능

- **전역 단축키** — 어떤 앱을 사용 중이든 포커스 전환 없이 패널 호출
- **플로팅 패널** — 다른 앱 위에 항상 표시, 작업 흐름 방해 없음
- **복사 후 자동 닫힘** — 클립보드에 복사하는 즉시 패널이 닫힘
- **텍스트 영속성** — 앱 재시작 후에도 마지막 프롬프트 자동 복원
- **단축키 커스터마이징** — 우클릭 메뉴에서 원하는 키 조합으로 변경

## 표시 항목

| 항목 | 설명 |
| ---- | ---- |
| **에디터** | 프롬프트 작성을 위한 모노스페이스 텍스트 영역 |
| **줄 수** | 타이틀 바에 실시간 표시 |
| **글자 수** | 타이틀 바에 실시간 표시 |
| **초기화** | 에디터 내용을 한 번에 삭제 |
| **클립보드에 복사** | 텍스트를 복사하고 패널을 자동으로 닫음 |

## 요구사항

- macOS 14 (Sonoma) 이상
- 외부 계정 또는 로그인 불필요

## 설치

```bash
git clone https://github.com/cyb9701/claude-tools.git
cd claude-tools/claude-prompt-pad
make install
```

`~/Applications/Claude PromptPad.app`에 앱을 빌드하고 설치합니다.

## 단축키 설정

메뉴바 아이콘 우클릭 → **단축키 설정...** 에서 전역 단축키를 원하는 키 조합으로 변경할 수 있습니다.

<!-- Screenshot: 단축키 녹화 패널 -->

![단축키 설정](screenshots/screenshot-shortcuts.png)

## 업데이트 및 제거

```bash
# 업데이트 (저장소 루트에서 실행)
git pull
cd claude-prompt-pad
make update

# 제거 (claude-prompt-pad/ 에서 실행)
make uninstall
```

## 라이선스

MIT
