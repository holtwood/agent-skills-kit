#!/usr/bin/env bash
#
# render_cover.sh — 渲染公众号头图（900×383@2x）与方形次图（500×500）
#
# 用法:
#   bash render_cover.sh <含 cover.html 的文章目录>
#   CHROME_BIN=/path/to/chrome bash render_cover.sh ./whenfree
#   bash render_cover.sh -h | --help
#
# 约定: <dir>/cover.html 与 assets/cover.html 模板同构 —— 头图区块 1800×766，
#       方形区块 1000×1000、与头图间距 8px；页面总高 1780。
# 输出: <dir>/img/cover.png、<dir>/img/cover-square.png
# 退出码: 0 成功 / 1 运行时错误 / 2 参数错误
#
set -euo pipefail

usage() { sed -n '2,12p' "$0"; exit "${1:-0}"; }
case "${1:-}" in
  -h|--help) usage 0 ;;
  "") echo "✗ 缺少参数：<含 cover.html 的文章目录>"; usage 2 >&2 ;;
  --*) echo "✗ 未知参数 $1"; usage 2 >&2 ;;
esac
DIR="$1"
[ -d "$DIR" ] || { echo "✗ 目录不存在: $DIR"; exit 2; }
[ -f "$DIR/cover.html" ] || { echo "✗ 未找到 $DIR/cover.html（模板在 skill 的 assets/cover.html，先复制过去改）"; exit 1; }
mkdir -p "$DIR/img"

# ---- 依赖预检：浏览器 / Python / Pillow ----
CHROME="${CHROME_BIN:-}"
if [ -z "$CHROME" ]; then
  for c in "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
           "/Applications/Chromium.app/Contents/MacOS/Chromium" \
           "$(command -v chromium 2>/dev/null || true)" \
           "$(command -v google-chrome 2>/dev/null || true)"; do
    [ -n "$c" ] && [ -x "$c" ] && CHROME="$c" && break
  done
fi
[ -n "$CHROME" ] || { echo "✗ 未找到 Chrome/Chromium，可用 CHROME_BIN 指定"; exit 1; }
command -v python3 >/dev/null || { echo "✗ 未找到 python3"; exit 1; }
python3 -c "import PIL" 2>/dev/null || { echo "✗ 缺 Pillow: pip3 install Pillow"; exit 1; }

# ---- 素材预检：cover.html 引用的本地图片必须存在 ----
MISSING=$(grep -o 'src="img/[^"]*"' "$DIR/cover.html" | sed 's/src="//;s/"//' | while read -r f; do
  [ -f "$DIR/$f" ] || echo "$f"
done)
[ -z "$MISSING" ] || { echo "✗ cover.html 引用的图片不存在: $MISSING"; exit 1; }

ABS_DIR="$(cd "$DIR" && pwd)"
"$CHROME" --headless=new --disable-gpu --hide-scrollbars \
  --screenshot="$ABS_DIR/cover-full.png" --window-size=1800,1780 \
  "file://$ABS_DIR/cover.html" 2>/dev/null

# ---- 布局验证：整页必须是 1800×1780，否则模板结构被改动，裁切坐标不可信 ----
python3 - "$ABS_DIR" <<'PY'
import sys
from PIL import Image
d = sys.argv[1]
im = Image.open(f"{d}/cover-full.png")
if im.size != (1800, 1780):
    sys.exit(f"✗ 渲染尺寸 {im.size} != (1800,1780)，cover.html 结构偏离模板，裁切坐标不可信")
im.crop((0, 0, 1800, 766)).save(f"{d}/img/cover.png")
im.crop((0, 774, 1000, 1774)).resize((500, 500), Image.LANCZOS).save(f"{d}/img/cover-square.png")
PY

rm -f "$ABS_DIR/cover-full.png"
echo "✅ 头图: $DIR/img/cover.png (1800x766) | 次图: $DIR/img/cover-square.png (500x500)"
