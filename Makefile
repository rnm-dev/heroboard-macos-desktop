.PHONY: help build clean zip all

help:
	@echo "Доступные команды:"
	@echo "  make build    - Собрать приложение"
	@echo "  make zip      - Создать ZIP архив (требует предварительной сборки)"
	@echo "  make all      - Собрать и упаковать в ZIP"
	@echo "  make clean    - Очистить build директорию"

build:
	@echo "🔨 Генерация Xcode проекта..."
	xcodegen
	@echo "🏗️  Сборка приложения..."
	xcodebuild -scheme Heroboard -configuration Release -derivedDataPath ./build
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
