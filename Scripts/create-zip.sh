#!/bin/bash

set -e

# Настройки
APP_NAME="Heroboard"
ZIP_NAME="macos-heroboard"
VERSION="${1:-dev}"

# Пути
BUILD_DIR="${BUILD_DIR:-build/Release}"
APP_PATH="${BUILD_DIR}/${APP_NAME}.app"

echo "🔍 Проверка наличия приложения..."
if [ ! -d "$APP_PATH" ]; then
    echo "❌ Приложение не найдено по пути: $APP_PATH"
    echo "💡 Сначала соберите приложение с помощью xcodebuild"
    exit 1
fi

echo "📦 Создание ZIP архива..."
rm -f "${ZIP_NAME}.zip"

# Используем ditto как в GitHub Actions для правильной упаковки
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "${ZIP_NAME}.zip"

echo "✅ ZIP файл создан: ${ZIP_NAME}.zip"
echo "📊 Размер файла:"
du -h "${ZIP_NAME}.zip"
