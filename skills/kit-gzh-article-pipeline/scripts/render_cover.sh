#!/usr/bin/env bash
#
# render_cover.sh — 渲染公众号头图（900×383@2x）与方形次图（500×500）
#
# 用法:
#   bash render_cover.sh <含 cover.html 的文章目录>
#   CHROME_BIN=/path/to/chrome bash render_cover.sh ./whenfree
#
# 约定: <dir>/cover.html 与模板同构 —— 含 1800×766 头图区块 + 顶部间距 8px 的 1000×1000 方形区块
# 输出: <dir>/img/cover.png、<dir>/img/cover-square.png
#
set -euo pipefail

DIR="${1:?用法: render_cover.sh <含 cover.html 的文章目录>}"
[ -f "$DIR/cover.html" ] || { echo "✗ 未找到 $DIR/cover.html"; exit 1; }
mkdir -p "$DIR/img"

# 探测浏览器: 环境变量优先，macOS Chrome 次之，PATH 上的 chrome 兜底
CHROME="${CHROME_BIN:-}"
if [ -z "$CHROME" ]; then
  for c in "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
           "/Applications/Chromium.app/Contents/MacOS/Chromium" \
           "$(command -v chromium 2>/dev/null || true)" \
           "$(command -v google-chrome 2>/dev/null || true)" \
           "$HOME/.cache/ms-playwright/chrome-headless-shell/chrome-headless-shell"; do
    [ -n "$c" ] && [ -x "$c" ] && CHROME="$c" && break
  done
fi
[ -n "$CHROME" ] || { echo "✗ 未找到 Chrome/Chromium，可用 CHROME_BIN 指定"; exit 1; }

ABS_DIR="$(cd "$DIR" && pwd)"
"$CHROME" --headless=new --disable-gpu --hide-scrollbars \
  --screenshot="$ABS_DIR/cover-full.png" --window-size=1800,1780 \
  "file://$ABS_DIR/cover.html" 2>/dev/null

python3 - "$ABS_DIR" <<'PY'
import sys
from PIL import Image
d = sys.argv[1]
im = Image.open(f"{d}/cover-full.png")
im.crop((0, 0, 1800, 766)).save(f"{d}/img/cover.png")
im.crop((0, 774, 1000, 1774)).resize((500, 500), Image.LANCZOS).save(f"{d}/img/cover-square.png")
PY

rm -f "$ABS_DIR/cover-full.png"
echo "✅ 头图: $DIR/img/cover.png (1800x766) | 次图: $DIR/img/cover-square.png (500x500)"
