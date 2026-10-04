#!/usr/bin/env python3
"""check_article.py — 公众号文章统一终检门禁。

用法:
    python3 check_article.py <文章目录>              # 检查目录内 article-gzh.html + article-gzh-embedded.html
    python3 check_article.py <文章目录> --html a.html --embedded b.html   # 指定文件
    python3 check_article.py --help

检查项（任何一项失败即退出码 1，全部通过才 0）:
  1. 可见文本规则：解码 HTML 实体后扫描全角冒号、破折号、弯双引号、{{占位符}}（humanizer 标点禁令）
  2. 图片完整性：所有 <img src> 本地路径必须存在；embedded 版必须全部为 data: 内嵌
  3. 双产物一致：存档版与 embedded 版图片数量一致，无本地路径残留
  4. gzh-design 合规校验：能找到校验器则调用，其警告与错误一律视为失败
退出码: 0 全过 / 1 有失败项 / 2 参数错误
"""
import argparse
import html
import pathlib
import re
import subprocess
import sys
from html.parser import HTMLParser

FORBIDDEN_TEXT = [
    ("——", "破折号"),
    ("：", "全角冒号"),
    ("\u201c", "弯双引号“"),
    ("\u201d", "弯双引号”"),
]
PLACEHOLDER_RE = re.compile(r"\{\{[^}]*\}\}")
IMG_RE = re.compile(r'<img\b[^>]*?src="([^"]+)"', re.IGNORECASE)


class VisibleText(HTMLParser):
    """抽取可见文本（跳过 style/script）。"""

    def __init__(self):
        super().__init__()
        self.parts = []
        self._skip = 0

    def handle_starttag(self, tag, attrs):
        if tag in ("style", "script"):
            self._skip += 1

    def handle_endtag(self, tag):
        if tag in ("style", "script") and self._skip:
            self._skip -= 1

    def handle_data(self, data):
        if not self._skip and data.strip():
            self.parts.append(data)


def visible_text(html_text: str) -> str:
    p = VisibleText()
    p.feed(html_text)
    # 实体可能以字符引用形式藏在属性或文本里，统一解码后再查
    return html.unescape("".join(p.parts))


def find_validator():
    import os
    candidates = [
        os.environ.get("GZH_DESIGN_HOME"),
        pathlib.Path(__file__).resolve().parent.parent.parent / "gzh-design" / "scripts" / "validate_gzh_html.py",
        pathlib.Path.home() / ".agents" / "skills" / "gzh-design" / "scripts" / "validate_gzh_html.py",
        pathlib.Path.home() / ".claude" / "skills" / "gzh-design" / "scripts" / "validate_gzh_html.py",
    ]
    for c in candidates:
        if c and pathlib.Path(c).is_file():
            return pathlib.Path(c)
    return None


def check_file(path: pathlib.Path, embedded: bool, findings: list) -> dict:
    text = path.read_text(encoding="utf-8")
    imgs = IMG_RE.findall(text)
    # 1. 可见文本规则（实体解码后）
    vis = visible_text(text)
    for pat, name in FORBIDDEN_TEXT:
        n = vis.count(pat)
        if n:
            findings.append(f"✗ {path.name}: 可见文本含{name} {n} 处（实体解码后仍命中）")
    for m in PLACEHOLDER_RE.finditer(vis):
        findings.append(f"✗ {path.name}: 残留占位符 {m.group(0)}")
    # 2. 图片完整性
    bad_ref = 0
    for src in imgs:
        if src.startswith("data:"):
            if not embedded:
                findings.append(f"✗ {path.name}: 存档版应为本地图片路径，却是 data: 内嵌（{src[:40]}…）")
                bad_ref += 1
        else:
            if embedded:
                findings.append(f"✗ {path.name}: embedded 版残留本地图片路径 {src}")
                bad_ref += 1
            elif not (path.parent / src).is_file():
                findings.append(f"✗ {path.name}: 图片不存在 {src}")
                bad_ref += 1
    return {"imgs": len(imgs), "bad": bad_ref}


def main() -> int:
    ap = argparse.ArgumentParser(description="公众号文章统一终检门禁（任何失败退出码 1）")
    ap.add_argument("directory", nargs="?", help="含排版产物的文章目录")
    ap.add_argument("--html", help="存档版文件名（默认 article-gzh.html）")
    ap.add_argument("--embedded", help="内嵌版文件名（默认 article-gzh-embedded.html）")
    args = ap.parse_args()
    if not args.directory:
        ap.print_help()
        return 2

    d = pathlib.Path(args.directory)
    f_html = d / (args.html or "article-gzh.html")
    f_emb = d / (args.embedded or "article-gzh-embedded.html")
    for f in (f_html, f_emb):
        if not f.is_file():
            print(f"✗ 缺少产物 {f}")
            return 1

    findings: list = []
    r1 = check_file(f_html, embedded=False, findings=findings)
    r2 = check_file(f_emb, embedded=True, findings=findings)
    if r1["imgs"] and r1["imgs"] != r2["imgs"]:
        findings.append(f"✗ 两份产物图片数量不一致: {f_html.name} {r1['imgs']} vs {f_emb.name} {r2['imgs']}")

    validator = find_validator()
    if validator:
        proc = subprocess.run([sys.executable, str(validator), str(f_html)],
                              capture_output=True, text=True)
        out = proc.stdout + proc.stderr
        if proc.returncode != 0 or "❌" in out or "WARNING" in out or "⚠" in out:
            findings.append("✗ gzh-design 校验未全绿（警告同样视为失败）:\n" + out.strip()[:800])
    else:
        print("⚠ 未找到 gzh-design 校验器（GZH_DESIGN_HOME 可指定），该项跳过")

    if findings:
        print("\n".join(findings))
        print(f"\n❌ 终检未通过: {len(findings)} 项")
        return 1
    print(f"✅ 终检通过: 文本规则 / 图片完整性 / 双产物一致"
          f"{'' if validator else '（gzh-design 校验器未找到，跳过）'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
