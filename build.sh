#!/usr/bin/env bash
# Builds the work-mode Telegram web client into ./site
#
# Needs Node.js 24+ and npm 11+. Usage:
#   ./build.sh
# Optional: WORK_FOLDERS="Работа,Проекты" (folders with 💼 in the title count as work folders anyway)
#
# The build has no Telegram API keys: each device asks for them once and keeps them locally
set -euo pipefail

UPSTREAM_REPO=https://github.com/Ajaxy/telegram-tt.git
UPSTREAM_COMMIT=293ede7b20390d04934f4beee6304c3560bbb5d6
OPUS_RECORDER_REPO=https://github.com/Ajaxy/opus-recorder.git
OPUS_RECORDER_COMMIT=116830a94120baad5ac60ac060c2ecd032b6107b
# Telegram's public Web Push key, the same one web.telegram.org uses
TELEGRAM_VAPID_KEY=BHEbKOXt-GD8MCTTYiAYT3I5R4MB0epIE7Tbbymj1uR0xJRE_7m27eXTVAC_P19TeZnO9413lRz-0oZ87JRPKPM

BASE_URL="${BASE_URL:-https://sonya1995.github.io/work-telegram/}"
WORK_FOLDERS="${WORK_FOLDERS:-}"

ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT

# Upstream keeps a prebuilt `dist` in the repository, so the checkout skips it
git clone --quiet --filter=blob:none --no-checkout "$UPSTREAM_REPO" "$BUILD_DIR/telegram-tt"
cd "$BUILD_DIR/telegram-tt"
git sparse-checkout set --no-cone '/*' '!/dist/'
git checkout --quiet "$UPSTREAM_COMMIT"
git apply "$ROOT/work-mode.patch"

# The voice recorder's prebuilt files are enough; its source submodules are not needed
git clone --quiet --filter=blob:none "$OPUS_RECORDER_REPO" "$BUILD_DIR/opus-recorder"
git -C "$BUILD_DIR/opus-recorder" checkout --quiet "$OPUS_RECORDER_COMMIT"
(cd "$BUILD_DIR/opus-recorder" && npm pack --silent --pack-destination "$BUILD_DIR" >/dev/null)
npm pkg set "dependencies.opus-recorder=file:$BUILD_DIR/opus-recorder-8.0.3.tgz"

npm install --no-audit --no-fund

TELEGRAM_API_ID= \
TELEGRAM_API_HASH= \
BASE_URL="$BASE_URL" \
WORK_FOLDERS="$WORK_FOLDERS" \
VAPID_KEY="$TELEGRAM_VAPID_KEY" \
APP_TITLE="Рабочий Telegram" \
npm run build:production

rm -rf "$ROOT/site"
mkdir -p "$ROOT/site"
(cd dist && tar --exclude='*.map' --exclude='build-stats.json' --exclude='statoscope-report.html' \
  --exclude='google*.html' -cf - .) | (cd "$ROOT/site" && tar -xf -)
# GitHub Pages must not run Jekyll over the build
touch "$ROOT/site/.nojekyll"

echo "Built into $ROOT/site"
