#!/usr/bin/env bash
set -euo pipefail

# 使用方式：
#   ./offline_vitepress_install.sh /path/to/vitepress-offline-bundle_<node>_<stamp> [DEST_DIR]
#   - 第一個參數：bundle 目錄（包含 project.tgz / npm-cache.tgz）
#   - 第二個參數(可選)：要把專案解壓到哪個路徑，預設為當前目錄下的 project/

BUNDLE_DIR="${1:-}"
DEST_DIR="${2:-$PWD/project}"

if [[ -z "$BUNDLE_DIR" ]]; then
  echo "用法：$0 /path/to/vitepress-offline-bundle_<node>_<stamp> [DEST_DIR]"
  exit 1
fi

[[ -d "$BUNDLE_DIR" ]] || { echo "❌ 找不到目錄：$BUNDLE_DIR"; exit 1; }
[[ -f "$BUNDLE_DIR/project.tgz"    ]] || { echo "❌ 缺少 $BUNDLE_DIR/project.tgz"; exit 1; }
[[ -f "$BUNDLE_DIR/npm-cache.tgz"  ]] || { echo "❌ 缺少 $BUNDLE_DIR/npm-cache.tgz"; exit 1; }

command -v node >/dev/null 2>&1 || { echo "❌ 離線機器未安裝 node"; exit 1; }
command -v npm  >/dev/null 2>&1  || { echo "❌ 離線機器未安裝 npm"; exit 1; }

NODE_VER="$(node -v)"
NPM_VER="$(npm -v)"
echo "👉 離線機 Node: $NODE_VER"
echo "👉 離線機 npm : $NPM_VER"

# 顯示 metadata（若存在）
if [[ -f "$BUNDLE_DIR/metadata.json" ]]; then
  echo "ℹ️  線上端 metadata："
  cat "$BUNDLE_DIR/metadata.json"
  echo
fi

# 1) 解壓 npm-cache
echo "📂 解壓 npm-cache 到 \$HOME/npm-cache"
mkdir -p "$HOME"
tar -xzf "$BUNDLE_DIR/npm-cache.tgz" -C "$HOME"
export NPM_CONFIG_CACHE="$HOME/npm-cache"

# 2) 解壓專案
echo "📂 解壓 project.tgz 到 $DEST_DIR"
mkdir -p "$DEST_DIR"
tar -xzf "$BUNDLE_DIR/project.tgz" -C "$DEST_DIR" --strip-components=1

# 3) 驗證可直接使用（優先直接用已附的 node_modules）
if [[ -d "$DEST_DIR/node_modules" ]]; then
  echo "✅ 已附帶 node_modules，可直接啟動開發伺服器："
  echo "   (cd \"$DEST_DIR\" && npm run docs:dev)"
else
  echo "⚠️ 找不到 node_modules，使用離線快取進行安裝 ..."
  (
    cd "$DEST_DIR"
    # 若你想保留 package-lock 的精準版本，建議用 ci；否則可改 install。
    npm ci --offline || npm install --offline
  )
fi

echo
echo "🚀 常用指令（於 $DEST_DIR 內）："
echo "   npm run docs:dev      # 開發模式（預設 http://localhost:5173）"
echo "   npm run docs:build    # 產出靜態網站到 docs/.vitepress/dist"
echo "   npm run docs:preview  # 本機預覽已編譯靜態網站"

