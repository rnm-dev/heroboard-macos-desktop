.PHONY: help build clean zip all

# Release version stamped into CFBundleShortVersionString (and the heartbeat `v` field).
# Auto-derives from the latest git tag (stripping a leading `v`); falls back to the
# `local-build` sentinel when untagged so dev builds keep Dependencies.isLocalDevBuild == true.
# Override explicitly with `make all VERSION=1.2.3`.
VERSION ?= $(shell git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//')
ifeq ($(strip $(VERSION)),)
VERSION := local-build
endif

help:
	@echo "Доступные команды:"
	@echo "  make build    - Собрать приложение"
	@echo "  make zip      - Создать ZIP архив (требует предварительной сборки)"
	@echo "  make all      - Собрать и упаковать в ZIP"
	@echo "  make clean    - Очистить build директорию"

build:
	@echo "🔨 Генерация Xcode проекта..."
	xcodegen
	@echo "🏗️  Сборка приложения (версия: $(VERSION))..."
	xcodebuild -scheme Heroboard -configuration Release -derivedDataPath ./build \
		MARKETING_VERSION=$(VERSION) CURRENT_PROJECT_VERSION=$(VERSION)
	@echo "✅ Сборка завершена!"
	@ls -lh build/Build/Products/Release/Heroboard.app

zip:
	@echo "📦 Упаковка в ZIP..."
	@BUILD_DIR=build/Build/Products/Release ./Scripts/create-zip.sh

all: build zip

clean:
	@echo "🧹 Очистка..."
	rm -rf build/
	rm -f macos-heroboard.zip
	@echo "✅ Очистка завершена!"
