APP_NAME    = ClaudeUsageBar
BUNDLE_ID   = com.claudeusagebar.app
INSTALL_DIR = $(HOME)/Applications
APP_BUNDLE  = $(INSTALL_DIR)/$(APP_NAME).app
BINARY_SRC  = .build/release/$(APP_NAME)

# ─── 기본 타겟 ────────────────────────────────────────────

.PHONY: all build install uninstall run clean help

all: help

## 도움말 출력
help:
	@echo ""
	@echo "ClaudeUsageBar — Claude 사용량 메뉴바 앱"
	@echo ""
	@echo "  make install    빌드 후 ~/Applications 에 설치 (최초 1회)"
	@echo "  make update     재빌드 후 기존 설치 업데이트"
	@echo "  make run        빌드 후 터미널에서 직접 실행 (개발용)"
	@echo "  make uninstall  ~/Applications 에서 삭제"
	@echo "  make clean      빌드 캐시 삭제"
	@echo ""

# ─── 빌드 ────────────────────────────────────────────────

## 릴리즈 바이너리 빌드
build:
	@echo "▶ 빌드 중..."
	@swift build -c release
	@echo "✓ 빌드 완료: $(BINARY_SRC)"

# ─── 설치 ────────────────────────────────────────────────

## .app 번들 생성 후 ~/Applications 에 설치
install: build
	@echo "▶ 설치 중: $(APP_BUNDLE)"
	@mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	@mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	@cp "$(BINARY_SRC)" "$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)"
	@cp Info.plist "$(APP_BUNDLE)/Contents/Info.plist"
	@# 코드 서명 (자체 서명 — App Store 외 배포)
	@codesign --force --deep --sign - "$(APP_BUNDLE)" 2>/dev/null || true
	@echo ""
	@echo "✅ 설치 완료!"
	@echo ""
	@echo "실행 방법:"
	@echo "  open $(APP_BUNDLE)"
	@echo ""
	@echo "로그인 시 자동 실행 설정:"
	@echo "  시스템 설정 → 일반 → 로그인 항목 → ClaudeUsageBar 추가"
	@echo ""
	@open "$(APP_BUNDLE)"

## 재빌드 후 실행 중인 앱 교체 (업데이트)
update: build
	@echo "▶ 업데이트 중..."
	@pkill -x "$(APP_NAME)" 2>/dev/null || true
	@sleep 0.5
	@cp "$(BINARY_SRC)" "$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)"
	@codesign --force --deep --sign - "$(APP_BUNDLE)" 2>/dev/null || true
	@open "$(APP_BUNDLE)"
	@echo "✅ 업데이트 완료"

# ─── 실행 (개발용) ────────────────────────────────────────

## 빌드 후 터미널에서 직접 실행 (Dock에 표시될 수 있음)
run: build
	@echo "▶ 실행 중 (개발 모드)..."
	@"$(BINARY_SRC)"

# ─── 제거 ────────────────────────────────────────────────

## 설치된 앱 삭제
uninstall:
	@pkill -x "$(APP_NAME)" 2>/dev/null || true
	@rm -rf "$(APP_BUNDLE)"
	@echo "✅ 삭제 완료: $(APP_BUNDLE)"

# ─── 정리 ────────────────────────────────────────────────

## 빌드 캐시 삭제
clean:
	@rm -rf .build
	@echo "✅ 빌드 캐시 삭제 완료"
