#!/usr/bin/env bash
#
# Прод-релиз Heroboard для macOS: собрать Release → подписать (Developer ID) →
# нотаризовать → собрать DMG → залить на сервер → обновить метаданные обновлятора.
#
#   usage:   VERSION=1.2.3 bin/release-prod.sh          # явная версия
#            bin/release-prod.sh                         # версия из последнего git-тега
#
# Конфиг через env (всё опционально, кроме версии):
#   DEVELOPER_ID_APP   "Developer ID Application: Name (TEAMID)" — БЕЗ него DMG не пройдёт
#                      Gatekeeper у юзеров (раздача вне App Store). Список: `security find-identity -v -p codesigning`
#   NOTARY_PROFILE     имя профиля notarytool (создать: `xcrun notarytool store-credentials`).
#                      Без него DMG не нотаризован → на чужих маках откроется только через ПКМ→Open.
#   HB_DIST_HOST       ssh-таргет сервера         (default root@94.247.128.103)
#   HB_DIST_DIR        каталог на сервере         (default /srv/heroboard-downloads/macos)
#   HB_DIST_URL        публичный базовый URL      (default https://heroboard.app/downloads/macos)
#
# ВАЖНО (обновлятор): аппа сейчас использует AppUpdater(owner:"heroboard", repo:"macos-heroboard"),
# который читает GitHub Releases, а НЕ этот серверный appcast. Чтобы self-hosted-обновления реально
# заработали, апдейтер в аппе надо переключить на чтение $HB_DIST_URL/appcast.xml (Sparkle) —
# это отдельная задача. Скрипт готовит серверную сторону; код аппы пока менять не нужно.
set -euo pipefail
cd "$(cd "$(dirname "$0")/.." && pwd)"   # корень репо macos-app

APP_NAME="Heroboard"
SCHEME="Heroboard"
DERIVED="build"
APP_PATH="$DERIVED/Build/Products/Release/$APP_NAME.app"

VERSION="${VERSION:-$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//')}"
[ -n "$VERSION" ] && [ "$VERSION" != "local-build" ] || { echo "❌ Нет версии. Задай VERSION=x.y.z или поставь git-тег."; exit 1; }

SSH_HOST="${HB_DIST_HOST:-root@94.247.128.103}"
REMOTE_DIR="${HB_DIST_DIR:-/srv/heroboard-downloads/macos}"
PUBLIC_BASE="${HB_DIST_URL:-https://heroboard.app/downloads/macos}"
DEVID_APP="${DEVELOPER_ID_APP:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"

DMG_NAME="$APP_NAME-$VERSION.dmg"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
log(){ printf '\n▶ %s\n' "$*"; }

# ── 1. сборка Release (подписываем сразу Developer ID, если задан — корректная inside-out подпись) ──
log "Сборка $APP_NAME $VERSION (Release)"
xcodegen
SIGN_ARGS=()
if [ -n "$DEVID_APP" ]; then
  SIGN_ARGS=(CODE_SIGN_STYLE=Manual "CODE_SIGN_IDENTITY=$DEVID_APP" PROVISIONING_PROFILE_SPECIFIER="")
else
  echo "⚠️  DEVELOPER_ID_APP не задан — сборка подписана dev-сертификатом. Для прод-раздачи задай DEVELOPER_ID_APP."
fi
xcodebuild -scheme "$SCHEME" -configuration Release -derivedDataPath "$DERIVED" \
  MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$VERSION" \
  "${SIGN_ARGS[@]}" -quiet
[ -d "$APP_PATH" ] || { echo "❌ Не найден собранный .app: $APP_PATH"; exit 1; }
[ -n "$DEVID_APP" ] && codesign --verify --strict --verbose=2 "$APP_PATH"

# ── 2. DMG (.app + симлинк на /Applications) ──
log "Сборка DMG → $DMG_NAME"
STAGE="$WORK/stage"; mkdir -p "$STAGE"
cp -R "$APP_PATH" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -ov -format UDZO "$WORK/$DMG_NAME" >/dev/null
[ -n "$DEVID_APP" ] && codesign --force --timestamp --sign "$DEVID_APP" "$WORK/$DMG_NAME"

# ── 3. нотаризация + staple ──
if [ -n "$NOTARY_PROFILE" ]; then
  log "Нотаризация (ждём вердикт Apple)…"
  xcrun notarytool submit "$WORK/$DMG_NAME" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$WORK/$DMG_NAME"
  xcrun stapler validate "$WORK/$DMG_NAME"
else
  echo "⚠️  NOTARY_PROFILE не задан — DMG НЕ нотаризован. У других юзеров Gatekeeper заблокирует. Настрой notarytool профиль."
fi

# ── 4. метаданные обновлятора ──
log "Метаданные обновлятора"
SIZE=$(stat -f%z "$WORK/$DMG_NAME")
SHA=$(shasum -a 256 "$WORK/$DMG_NAME" | awk '{print $1}')
PUBDATE=$(date -u +"%a, %d %b %Y %H:%M:%S +0000")
URL="$PUBLIC_BASE/$DMG_NAME"

cat > "$WORK/latest.json" <<JSON
{
  "version": "$VERSION",
  "url": "$URL",
  "dmg": "$DMG_NAME",
  "sha256": "$SHA",
  "size": $SIZE,
  "pubDate": "$PUBDATE",
  "minimumSystemVersion": "10.15"
}
JSON

# Sparkle-совместимый appcast (single latest item). Если перейдёте на Sparkle с проверкой подписи —
# добавьте sparkle:edSignature через `sign_update` (нужен Sparkle-ключ).
cat > "$WORK/appcast.xml" <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>$APP_NAME</title>
    <item>
      <title>$VERSION</title>
      <pubDate>$PUBDATE</pubDate>
      <sparkle:version>$VERSION</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>10.15</sparkle:minimumSystemVersion>
      <enclosure url="$URL" sparkle:version="$VERSION" length="$SIZE" type="application/x-apple-diskimage" />
    </item>
  </channel>
</rss>
XML

# ── 5. заливка на сервер ──
log "Заливка → $SSH_HOST:$REMOTE_DIR"
ssh "$SSH_HOST" "mkdir -p '$REMOTE_DIR'"
scp "$WORK/$DMG_NAME" "$WORK/latest.json" "$WORK/appcast.xml" "$SSH_HOST:$REMOTE_DIR/"

cat <<DONE

✅ Готово — $APP_NAME $VERSION
   DMG     : $URL
   manifest: $PUBLIC_BASE/latest.json  и  $PUBLIC_BASE/appcast.xml
   sha256  : $SHA   size: $SIZE

Напоминания:
  • Публичный /downloads/ на :443 (Cloudflare) пока не поднят — заливка ляжет на сервер,
    но по https скачиваться НЕ будет, пока не добавим :443-блок nginx (мы это паузили на выборе серта).
  • Обновлятор аппы (AppUpdater) читает GitHub Releases, а не этот appcast — для self-hosted
    обновлений переключить апдейтер на $PUBLIC_BASE/appcast.xml (отдельная задача).
DONE
