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
#       方形区块 1000×1000、与头图间距 8px（getBoundingClientRect 实测校验）。
# 输出: <dir>/img/cover.png、<dir>/img/cover-square.png
# 退出码: 0 成功 / 1 运行时错误（含布局/资源/占位符检查不过）/ 2 参数错误
#
set -euo pipefail

usage() { sed -n '2,13p' "$0"; exit "${1:-0}"; }
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

# ---- 占位符扫描：源码级，覆盖 style / 属性 / 正文（DOM innerText 看不到 <style>），排除说明注释 ----
python3 - "$DIR/cover.html" <<'PY'
import re, sys, pathlib
t = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
t = re.sub(r"<!--.*?-->", "", t, flags=re.S)
found = sorted(set(re.findall(r"\{\{[^}]*\}\}", t)))
if found:
    print("✗ cover.html 存在未替换的占位符（含样式/属性）: " + ", ".join(found))
    sys.exit(1)
PY

ABS_DIR="$(cd "$DIR" && pwd)"

# ---- 布局实测：注入测量脚本，dump-dom 取回 getBoundingClientRect / 图片加载 / 占位符 ----
python3 - "$ABS_DIR" <<'PY'
import pathlib, sys
d = pathlib.Path(sys.argv[1])
t = (d / "cover.html").read_text(encoding="utf-8")
inject = (
    '<pre id="wf-layout" style="display:none">PENDING</pre>\n<script>\n'
    "window.addEventListener('load', function(){\n"
    "  var o = {};\n"
    "  var covers = document.querySelectorAll('.cover');\n"
    "  if (covers[0]) { var r = covers[0].getBoundingClientRect(); o.cover = [r.width, r.height, r.top]; }\n"
    "  if (covers[1]) { var r2 = covers[1].getBoundingClientRect(); o.square = [r2.width, r2.height, r2.top]; }\n"
    "  o.imgs = Array.prototype.map.call(document.images, function(i){ return i.naturalWidth; });\n"
    "  document.getElementById('wf-layout').textContent = JSON.stringify(o);\n"
    "});\n</script>\n"
)
low = t.lower()
(d / ".wf-check.html").write_text(t.replace("</body>", inject + "</body>") if "</body>" in low else t + inject,
                                  encoding="utf-8")
PY
DUMP=$("$CHROME" --headless=new --disable-gpu --dump-dom --virtual-time-budget=10000 \
       "file://$ABS_DIR/.wf-check.html" 2>/dev/null || true)
rm -f "$ABS_DIR/.wf-check.html"
printf '%s' "$DUMP" > "$ABS_DIR/.wf-dump.html"
python3 - "$ABS_DIR/.wf-dump.html" <<'PY'
import json, re, sys, pathlib
dump = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
m = re.search(r'<pre id="wf-layout"[^>]*>(.*?)</pre>', dump, re.S)
bad = []
if not m or m.group(1).strip() in ("", "PENDING"):
    bad.append("未能取回布局测量结果（headless dump-dom 或 load 事件未执行）")
else:
    o = json.loads(m.group(1))
    cover, square, imgs = o.get("cover"), o.get("square"), o.get("imgs")
    if not cover or round(cover[0]) != 1800 or round(cover[1]) != 766:
        bad.append(f"头图区块实测 {cover}，应为 1800×766 —— cover.html 头图结构偏离模板")
    if not square or round(square[0]) != 1000 or round(square[1]) != 1000 or not (770 <= round(square[2]) <= 778):
        bad.append(f"方形区块实测 {square}，应为 1000×1000、top≈774 —— 方形区块结构偏离模板")
    if any(w <= 0 for w in (imgs or [])):
        bad.append(f"存在未加载成功的图片（naturalWidth={imgs}）")
if bad:
    print("\n".join("✗ " + b for b in bad))
    sys.exit(1)
print("✅ 布局实测通过: 头图 1800×766 / 方形 1000×1000@774 / 图片全部加载")
PY
rm -f "$ABS_DIR/.wf-dump.html"

# ---- 渲染与裁切（窗口尺寸检查保留作辅助；真正的布局信任来自上面的 DOM 实测） ----
"$CHROME" --headless=new --disable-gpu --hide-scrollbars \
  --screenshot="$ABS_DIR/cover-full.png" --window-size=1800,1780 \
  "file://$ABS_DIR/cover.html" 2>/dev/null

python3 - "$ABS_DIR" <<'PY'
import sys
from PIL import Image
d = sys.argv[1]
im = Image.open(f"{d}/cover-full.png")
if im.size != (1800, 1780):
    sys.exit(f"✗ 截图尺寸 {im.size} != (1800,1780)，渲染环境异常")
im.crop((0, 0, 1800, 766)).save(f"{d}/img/cover.png")
im.crop((0, 774, 1000, 1774)).resize((500, 500), Image.LANCZOS).save(f"{d}/img/cover-square.png")
PY

rm -f "$ABS_DIR/cover-full.png"
echo "✅ 头图: $DIR/img/cover.png (1800x766) | 次图: $DIR/img/cover-square.png (500x500)"
