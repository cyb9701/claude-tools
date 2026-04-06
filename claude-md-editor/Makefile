APP_NAME     = Claude MD Editor
BINARY_NAME  = ClaudeMDEditor
BUNDLE_ID    = com.claudemdeditor.app
INSTALL_DIR  = $(HOME)/Applications
APP_BUNDLE   = $(INSTALL_DIR)/$(APP_NAME).app
BINARY_SRC   = .build/release/$(BINARY_NAME)
CERT_NAME    ?= $(CODESIGN_CERT_NAME)
TEAM_ID      ?= $(CODESIGN_TEAM_ID)
ENTITLEMENTS = ClaudeMDEditor.entitlements

-include Makefile.local

.PHONY: all build install update uninstall run clean help _codesign

all: help

## 도움말 출력
help:
	@echo ""
	@echo "Claude MD Editor — 마크다운 에디터 메뉴바 앱"
	@echo ""
	@echo "  make install    빌드 후 ~/Applications 에 설치 (최초 1회)"
	@echo "  make update     재빌드 후 기존 설치 업데이트"
	@echo "  make run        빌드 후 터미널에서 직접 실행 (개발용)"
	@echo "  make uninstall  ~/Applications 에서 삭제"
	@echo "  make clean      빌드 캐시 삭제"
	@echo ""

## 릴리즈 바이너리 빌드
build:
	@echo "▶ 빌드 중..."
	@swift build -c release
	@echo "✓ 빌드 완료: $(BINARY_SRC)"

## Apple Developer 인증서로 코드서명, 미존재 시 ad-hoc 폴백
_codesign:
	@codesign --force --deep \
	    --sign "$(CERT_NAME)" \
	    --entitlements "$(ENTITLEMENTS)" \
	    "$(APP_BUNDLE)" 2>/dev/null || \
	  codesign --force --deep --sign - "$(APP_BUNDLE)" 2>/dev/null || true

## .app 번들 생성 후 ~/Applications 에 설치
install: build
	@echo "▶ 설치 중: $(APP_BUNDLE)"
	@mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	@mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	@cp "$(BINARY_SRC)" "$(APP_BUNDLE)/Contents/MacOS/$(BINARY_NAME)"
	@cp Info.plist "$(APP_BUNDLE)/Contents/Info.plist"
	@$(MAKE) _codesign
	@echo ""
	@echo "✅ 설치 완료!"
	@open "$(APP_BUNDLE)"

## 재빌드 후 실행 중인 앱 교체
update: build
	@echo "▶ 업데이트 중..."
	@pkill -x "$(BINARY_NAME)" 2>/dev/null || true
	@sleep 0.5
	@cp "$(BINARY_SRC)" "$(APP_BUNDLE)/Contents/MacOS/$(BINARY_NAME)"
	@cp Info.plist "$(APP_BUNDLE)/Contents/Info.plist"
	@$(MAKE) _codesign
	@open "$(APP_BUNDLE)"
	@echo "✅ 업데이트 완료"

## 빌드 후 터미널에서 직접 실행 (개발용)
run: build
	@echo "▶ 실행 중 (개발 모드)..."
	@"$(BINARY_SRC)"

## 설치된 앱 삭제
uninstall:
	@pkill -x "$(BINARY_NAME)" 2>/dev/null || true
	@rm -rf "$(APP_BUNDLE)"
	@echo "✅ 삭제 완료: $(APP_BUNDLE)"

## 빌드 캐시 삭제
clean:
	@rm -rf .build
	@echo "✅ 빌드 캐시 삭제 완료"
