#!/usr/bin/env python3
"""check_article.py — 公众号文章统一终检门禁。

用法:
    python3 check_article.py <文章目录>              # 检查目录内 article-gzh.html + article-gzh-embedded.html
    python3 check_article.py <文章目录> --html a.html --embedded b.html   # 指定文件
    python3 check_article.py --help

检查项（任何一项失败即退出码 1，全部通过才 0）:
  1. 可见文本规则：HTMLParser 抽取可见文本（charref 已解码），扫描 {{占位符}}；--text-policy legacy 时额外限制标点
  2. 图片完整性：存档版 <img> 用 HTMLParser 按属性抽取（单双引号都识别），本地路径必须存在、
     不允许 data: 内嵌；embedded 版必须为 data:image/<mime>;base64, 形式，base64 严格解码且
     用 Pillow 实际解码验证（防 4 字节假 PNG、RIFF 伪装、缺 base64 标记）；本地图片同样用 Pillow 解码
  3. 双产物一致：可见正文逐字一致（归一化空白后）、图片数量无条件相等、对应图片内容摘要一致
  4. 非空正文：两份产物可见文本均 ≥ 50 字
  5. 禁用标签：script / iframe / link / object / embed 任何位置都不允许
  6. gzh-design 兼容校验：校验器必须可用（缺失 = 失败，不降级跳过，与依赖契约一致），
     对两份产物分别调用；其输出含 ⚠️/❌/ERROR/WARNING 或退出码非 0 即失败

依赖: 标准库 + Pillow（图片实际解码）。

校验器接口约定（升级 gzh-design 后必跑 tests/regression.py）:
  validate_gzh_html.py <单个HTML路径>；退出码 0 且输出不含 ⚠️/❌/ERROR/WARNING 才算全绿。

GZH_DESIGN_HOME: 可指向校验器文件，或 gzh-design skill 目录（自动解析到 scripts/validate_gzh_html.py）；
  显式配置解析不到文件时直接判失败，不回退到其他安装副本。

退出码: 0 全过 / 1 有失败项 / 2 参数错误
"""
import argparse
import base64
import hashlib
import json
import os
import pathlib
import re
import subprocess
import sys
from html.parser import HTMLParser
from urllib.parse import unquote, urlsplit

FORBIDDEN_TEXT = [
    ("——", "破折号"),
    ("：", "全角冒号"),
    ("\u201c", "弯双引号“"),
    ("\u201d", "弯双引号”"),
]
PLACEHOLDER_RE = re.compile(r"\{\{[^}]*\}\}")
FORBIDDEN_TAGS = {"script", "iframe", "link", "object", "embed"}
MIN_TEXT_LEN = 50
# data URI 必须显式声明 base64 与受支持的图片 MIME
DATA_URI_RE = re.compile(r"^data:image/(png|jpeg|jpg|gif|webp);base64,([A-Za-z0-9+/=\r\n]+)$")
VALIDATOR_OUT_FAIL_RE = re.compile(r"⚠|❌|ERROR|WARNING", re.IGNORECASE)


def decode_image(raw: bytes, label: str, findings: list) -> bool:
    """用 Pillow 实际解码，任何损坏/伪装都算失败。"""
    import io
    try:
        from PIL import Image
    except ImportError:
        findings.append(f"✗ {label}: 缺 Pillow，无法做图片解码验证（pip3 install Pillow）")
        return False
    try:
        img = Image.open(io.BytesIO(raw))
        img.load()
        return True
    except Exception as e:
        findings.append(f"✗ {label}: 图片无法被 Pillow 解码（{type(e).__name__}: {e}）")
        return False


class PageParser(HTMLParser):
    """抽取可见文本（charref 自动解码）、img src 序列、出现的标签集合。"""

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.parts = []
        self.imgs = []          # [(src, line)] 按出现顺序
        self.tags = set()
        self._skip = 0

    def handle_starttag(self, tag, attrs):
        t = tag.lower()
        self.tags.add(t)
        if t in ("style", "script"):
            self._skip += 1
        if t == "img":
            d = dict(attrs)
            self.imgs.append((d.get("src", "").strip(), self.getpos()[0]))

    def handle_startendtag(self, tag, attrs):
        self.handle_starttag(tag, attrs)

    def handle_endtag(self, tag):
        if tag in ("style", "script") and self._skip:
            self._skip -= 1

    def handle_data(self, data):
        if not self._skip and data.strip():
            self.parts.append(data)


def parse_page(text: str):
    p = PageParser()
    p.feed(text)
    visible = "".join(p.parts)
    return visible, p.imgs, p.tags


def check_image(src: str, embedded: bool, parent: pathlib.Path, line: int, findings: list):
    if embedded:
        m = DATA_URI_RE.match(src)
        if not m:
            findings.append(f"✗ L{line}: embedded 版图片 data URI 不合规"
                            f"（须为 data:image/png|jpeg|gif|webp;base64,…，实际 {src[:56]}）")
            return None
        try:
            raw = base64.b64decode(m.group(2).replace("\r", "").replace("\n", ""), validate=True)
        except Exception:
            findings.append(f"✗ L{line}: embedded 版图片 base64 损坏，无法解码（{src[:48]}…）")
            return None
        if not decode_image(raw, f"L{line} 内嵌图片", findings):
            return None
        return hashlib.sha256(raw).hexdigest()
    if src.startswith("data:"):
        findings.append(f"✗ L{line}: 存档版应为本地图片路径，却是 data: 内嵌（{src[:48]}…）")
        return None
    uri = urlsplit(src)
    if uri.scheme or uri.netloc:
        findings.append(f"✗ L{line}: 存档版图片须为本地路径（{src[:80]}）")
        return None
    f = parent / unquote(uri.path)
    if not f.is_file():
        findings.append(f"✗ L{line}: 图片不存在 {src}")
        return None
    raw = f.read_bytes()
    if not decode_image(raw, f"{src}", findings):
        return None
    return hashlib.sha256(raw).hexdigest()


def check_file(path: pathlib.Path, embedded: bool, findings: list, text_policy="standard"):
    text = path.read_text(encoding="utf-8")
    visible, imgs, tags = parse_page(text)
    # 1. 可见文本规则
    for pat, name in FORBIDDEN_TEXT if text_policy == "legacy" else []:
        n = visible.count(pat)
        if n:
            findings.append(f"✗ {path.name}: 可见文本含{name} {n} 处")
    for m in PLACEHOLDER_RE.finditer(text):
        findings.append(f"✗ {path.name}: 残留占位符 {m.group(0)}")
    # 2. 非空正文
    if len(visible.strip()) < MIN_TEXT_LEN:
        findings.append(f"✗ {path.name}: 可见正文为空或过短（{len(visible.strip())} 字符 < {MIN_TEXT_LEN}）")
    # 3. 禁用标签
    bad_tags = tags & FORBIDDEN_TAGS
    if bad_tags:
        findings.append(f"✗ {path.name}: 含禁用标签 {sorted(bad_tags)}")
    # 4. 图片
    digests = [check_image(src, embedded, path.parent, line, findings) for src, line in imgs]
    return {"visible": visible, "imgs": len(imgs), "digests": digests}


def locate_validator(findings: list):
    """定位 gzh-design 校验器。显式配置解析不到 → 失败（不回退其他副本）。"""
    env = os.environ.get("GZH_DESIGN_HOME", "").strip()
    candidates = []
    if env:
        p = pathlib.Path(env)
        cand = p if p.is_file() else p / "scripts" / "validate_gzh_html.py"
        if not cand.is_file():
            findings.append(f"✗ GZH_DESIGN_HOME={env} 解析不到校验器（{cand} 不存在），"
                            "按依赖契约判失败，不回退其他安装副本")
            return None
        return cand
    for base in (pathlib.Path(__file__).resolve().parent.parent.parent / "gzh-design",
                 pathlib.Path.home() / ".agents" / "skills" / "gzh-design",
                 pathlib.Path(os.environ.get("CODEX_HOME", str(pathlib.Path.home() / ".codex"))) / "skills" / "gzh-design",
                 pathlib.Path.home() / ".config" / "opencode" / "skills" / "gzh-design",
                 pathlib.Path.home() / ".claude" / "skills" / "gzh-design"):
        candidates.append(base / "scripts" / "validate_gzh_html.py")
    for c in candidates:
        if c.is_file():
            return c
    findings.append("✗ 未找到 gzh-design 校验器（~/.agents/skills/gzh-design 等；"
                    "可用 GZH_DESIGN_HOME 指定）。按依赖契约，校验器缺失 = 终检失败")
    return None


def run_validator(validator, f: pathlib.Path, findings: list, timeout=30):
    try:
        proc = subprocess.run([sys.executable, str(validator), str(f)], capture_output=True,
                              text=True, encoding="utf-8", errors="replace", timeout=timeout)
    except (OSError, subprocess.TimeoutExpired) as exc:
        findings.append(f"✗ gzh-design 校验无法完成: {f.name}（{type(exc).__name__}）")
        return
    out = (proc.stdout + proc.stderr).strip()
    if proc.returncode != 0 or VALIDATOR_OUT_FAIL_RE.search(out):
        findings.append(f"✗ gzh-design 校验未全绿: {f.name}\n{out[:800]}")


def main() -> int:
    ap = argparse.ArgumentParser(description="公众号文章统一终检门禁（任何失败退出码 1；校验器缺失也是失败）")
    ap.add_argument("directory", nargs="?", help="含排版产物的文章目录")
    ap.add_argument("--html", help="存档版文件名（默认 article-gzh.html）")
    ap.add_argument("--embedded", help="内嵌版文件名（默认 article-gzh-embedded.html）")
    ap.add_argument("--text-policy", choices=("standard", "legacy"), default="standard",
                    help="standard 允许普通标点；legacy 启用历史标点限制")
    ap.add_argument("--validator-timeout", type=float, default=30, help="单份外部校验超时秒数（默认 30，上限 300）")
    ap.add_argument("--json", action="store_true", help="输出机器可读检查结果")
    args = ap.parse_args()
    if not args.directory:
        ap.print_help()
        return 2
    if not 0 < args.validator_timeout <= 300:
        ap.error("--validator-timeout 必须在 (0, 300] 内")

    d = pathlib.Path(args.directory)
    f_html = d / (args.html or "article-gzh.html")
    f_emb = d / (args.embedded or "article-gzh-embedded.html")
    findings: list = []
    for f in (f_html, f_emb):
        if not f.is_file():
            findings.append(f"✗ 缺少产物 {f}")
    if findings:
        return emit_result(args, findings)
    try:
        r1 = check_file(f_html, embedded=False, findings=findings, text_policy=args.text_policy)
        r2 = check_file(f_emb, embedded=True, findings=findings, text_policy=args.text_policy)
    except (OSError, UnicodeError, ValueError) as exc:
        findings.append(f"✗ 读取产物失败: {exc}")
        return emit_result(args, findings)
    # 双产物一致：图片数量无条件比较；正文归一化后逐字比较；图片逐张摘要比较
    if r1["imgs"] != r2["imgs"]:
        findings.append(f"✗ 两份产物图片数量不一致: {f_html.name} {r1['imgs']} vs {f_emb.name} {r2['imgs']}")
    elif r1["digests"] and r1["digests"] != r2["digests"]:
        findings.append("✗ 两份产物图片内容不一致（顺序或字节不同）")
    norm = lambda s: re.sub(r"\s+", "", s)
    if norm(r1["visible"]) != norm(r2["visible"]):
        findings.append("✗ 两份产物可见正文不一致（归一化空白后仍有差异）")

    validator = locate_validator(findings)
    if validator:
        run_validator(validator, f_html, findings, timeout=args.validator_timeout)
        run_validator(validator, f_emb, findings, timeout=args.validator_timeout)

    return emit_result(args, findings, validator)


def emit_result(args, findings, validator=None):
    code = 1 if findings else 0
    if args.json:
        print(json.dumps({"ok": not findings, "command": "check_article", "exitCode": code,
                          "textPolicy": args.text_policy, "findings": findings,
                          "validator": str(validator) if validator else None}, ensure_ascii=False, indent=2))
        return code

    if findings:
        print("\n".join(findings))
        print(f"\n❌ 终检未通过: {len(findings)} 项")
        return 1
    print(f"✅ 终检通过: 文本规则 / 图片完整性 / 双产物一致 / 非空正文 / 禁用标签 / "
          f"gzh-design 校验（{validator.name if validator else ''}）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
