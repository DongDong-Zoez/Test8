#!/usr/bin/env bash
set -euo pipefail

# ===== 可調參數 =====
VITEPRESS_VERSION="${VITEPRESS_VERSION:-latest}"  # 例如：1.5.0 或 latest
PROJECT_NAME="${PROJECT_NAME:-vitepress-site}"     # 專案資料夾名稱
OUT_DIR="${OUT_DIR:-$PWD}"                         # 輸出 bundle 的位置
CACHE_DIR="${CACHE_DIR:-$PWD/npm-cache}"           # npm 快取資料夾
BUNDLE_NAME="${BUNDLE_NAME:-vitepress-offline-bundle}"

# ===== 先決條件檢查 =====
command -v node >/dev/null 2>&1 || { echo "❌ node 未安裝"; exit 1; }
command -v npm  >/dev/null 2>&1 || { echo "❌ npm 未安裝"; exit 1; }

NODE_VER="$(node -v)"
NPM_VER="$(npm -v)"
echo "👉 Node: $NODE_VER"
echo "👉 npm : $NPM_VER"

# ===== 建立最小可跑的 VitePress 專案骨架 =====
WORKDIR="$(mktemp -d)"
SITE_DIR="$WORKDIR/$PROJECT_NAME"
mkdir -p "$SITE_DIR/docs/.vitepress"

cat > "$SITE_DIR/package.json" <<'JSON'
{
  "name": "vitepress-offline-demo",
  "private": true,
  "scripts": {
    "docs:dev": "vitepress dev docs",
    "docs:build": "vitepress build docs",
    "docs:preview": "vitepress preview docs"
  },
  "devDependencies": {
    "vitepress": "REPLACE_VP_VERSION"
  }
}
JSON
# 寫入版本
sed -i.bak "s/REPLACE_VP_VERSION/$VITEPRESS_VERSION/g" "$SITE_DIR/package.json" && rm -f "$SITE_DIR/package.json.bak"

# 預設首頁
cat > "$SITE_DIR/docs/index.md" <<'MD'
# Hello VitePress (Offline Ready)

- 這是可離線部署的最小示例
- 指令：
  - `npm run docs:dev`
  - `npm run docs:build`
  - `npm run docs:preview`
MD

# 最小 config
cat > "$SITE_DIR/docs/.vitepress/config.mjs" <<'MJS'
export default {
  title: 'VitePress Offline Demo',
  description: 'A minimal site bundled for offline install',
}
MJS

# ===== 安裝並填滿 npm 快取 =====
export NPM_CONFIG_CACHE="$CACHE_DIR"
mkdir -p "$CACHE_DIR"
echo "📦 線上安裝依賴並填滿 npm-cache ..."
(
  cd "$SITE_DIR"
  npm install
  npx --yes vitepress --version >/dev/null || true
)

# ===== 打包產物 =====
STAMP="$(date +%Y%m%d-%H%M%S)"
BUNDLE_DIR="$OUT_DIR/${BUNDLE_NAME}_${NODE_VER#v}_$STAMP"
mkdir -p "$BUNDLE_DIR"

# 1) 打包 npm-cache
echo "🗜️ 打包 npm-cache -> $BUNDLE_DIR/npm-cache.tgz"
tar -czf "$BUNDLE_DIR/npm-cache.tgz" -C "$(dirname "$CACHE_DIR")" "$(basename "$CACHE_DIR")"

# 2) 打包整個 VitePress 專案（含 node_modules）
echo "🗜️ 打包專案 -> $BUNDLE_DIR/project.tgz"
tar -czf "$BUNDLE_DIR/project.tgz" -C "$WORKDIR" "$PROJECT_NAME"

# 3) Metadata
cat > "$BUNDLE_DIR/metadata.json" <<EOF
{
  "node_version": "$NODE_VER",
  "npm_version": "$NPM_VER",
  "vitepress_version": "$VITEPRESS_VERSION",
  "project_name": "$PROJECT_NAME",
  "created_at": "$STAMP"
}
EOF

echo
echo "🎁 完成！離線包位於：$BUNDLE_DIR"
echo "   - npm-cache.tgz"
echo "   - project.tgz (含 node_modules)"
echo "   - metadata.json"
echo
echo "➡️  把整個資料夾帶到離線機器後，執行："
echo "    ./offline_vitepress_install.sh /path/to/${BUNDLE_DIR}"

