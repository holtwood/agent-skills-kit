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
[[ $# -eq 1 ]] || { echo "✗ 多余参数" >&2; exit 2; }
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

# ---- 本地素材预检：识别单双引号与 URL 编码路径 ----
python3 - "$DIR/cover.html" <<'PYIMG'
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlsplit, unquote
import sys
p = Path(sys.argv[1])
class Images(HTMLParser):
    def handle_starttag(self, tag, attrs):
        if tag == 'img':
            src = dict(attrs).get('src', '')
            uri = urlsplit(src)
            if not src or (not uri.scheme and not uri.netloc and not (p.parent / unquote(uri.path)).is_file()):
                sys.exit(f"✗ cover.html 图片不存在: {src}")
Images().feed(p.read_text(encoding='utf-8'))
PYIMG

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
CHECK_BASE="$(mktemp "$ABS_DIR/.wf-check.XXXXXX")"
CHECK_FILE="$CHECK_BASE.html"
mv "$CHECK_BASE" "$CHECK_FILE"
DUMP_FILE="$(mktemp "$ABS_DIR/.wf-dump.XXXXXX")"
FULL_BASE="$(mktemp "$ABS_DIR/.wf-full.XXXXXX")"
FULL_FILE="$FULL_BASE.png"
mv "$FULL_BASE" "$FULL_FILE"
trap 'rm -f "$CHECK_FILE" "$DUMP_FILE" "$FULL_FILE"' EXIT

# Bound each browser call; headless exit 0 alone is not success.
run_chrome() {
  python3 - "$CHROME" "$@" <<'PYCHROME'
import subprocess, sys
try:
    p = subprocess.run([sys.argv[1], '--no-first-run', '--no-default-browser-check',
                        '--no-sandbox', '--force-device-scale-factor=1', *sys.argv[2:]],
                       stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=45)
    sys.stdout.buffer.write(p.stdout)
    if p.returncode:
        sys.stderr.buffer.write(p.stderr[-2000:])
        sys.exit(1)
except (OSError, subprocess.TimeoutExpired) as exc:
    sys.exit(f'✗ Chrome 调用失败: {exc}')
PYCHROME
}

# ---- 布局实测：注入测量脚本，dump-dom 取回 getBoundingClientRect / 图片加载 / 占位符 ----
python3 - "$ABS_DIR" "$CHECK_FILE" <<'PY'
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
import re
pathlib.Path(sys.argv[2]).write_text(re.sub(r"</body>", lambda m: inject + m.group(0), t, count=1, flags=re.I) if "</body>" in low else t + inject,
                                  encoding="utf-8")
PY
DUMP=$(run_chrome --headless=new --disable-gpu --dump-dom --virtual-time-budget=10000 \
       "file://$CHECK_FILE")
printf '%s' "$DUMP" > "$DUMP_FILE"
python3 - "$DUMP_FILE" <<'PY'
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

# ---- 渲染与裁切（窗口尺寸检查保留作辅助；真正的布局信任来自上面的 DOM 实测） ----
run_chrome --headless=new --disable-gpu --hide-scrollbars \
  --screenshot="$FULL_FILE" --window-size=1800,1780 \
  "file://$ABS_DIR/cover.html"

python3 - "$ABS_DIR" "$FULL_FILE" <<'PY'
import sys
from PIL import Image
d = sys.argv[1]
im = Image.open(sys.argv[2])
if im.size != (1800, 1780):
    sys.exit(f"✗ 截图尺寸 {im.size} != (1800,1780)，渲染环境异常")
im.crop((0, 0, 1800, 766)).save(f"{d}/img/cover.png")
im.crop((0, 774, 1000, 1774)).resize((500, 500), Image.LANCZOS).save(f"{d}/img/cover-square.png")
PY

echo "✅ 头图: $DIR/img/cover.png (1800x766) | 次图: $DIR/img/cover-square.png (500x500)"
