#!/usr/bin/env python3
"""regression.py — check_article.py 的假通过反例回归测试。

用法:
    python3 tests/regression.py          # 全部反例 + 正例
    python3 tests/regression.py -v       # 详细输出

反例来自两轮外部评审的实测发现，改 check_article.py 后必须全绿。
测试用 stub 校验器（静默通过）隔离被测逻辑；校验器本身的对接由
「真实文章冒烟」用例覆盖（本机装有 gzh-design 且存在试点文章时运行）。
"""
import base64
import os
import pathlib
import subprocess
import sys
import tempfile
import unittest

SKILL = pathlib.Path(__file__).resolve().parent.parent
CHECK = SKILL / "scripts" / "check_article.py"
STUB_VALIDATOR = SKILL / "tests" / "fixtures" / "stub_validator.py"

# 1x1 透明 PNG
TINY_PNG = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==")
TINY_PNG_B64 = base64.b64encode(TINY_PNG).decode()
BODY = ("大家好，这是一段足够长的可见正文文本，用来通过终检的最小长度检查。"
        "正文里没有任何禁用标点与占位符，两份产物保持逐字一致。")
GOOD_TEXT = f"<section><p><span leaf=\"\">{BODY}</span></p>{{IMG}}</section>"


def good_pair(d: pathlib.Path):
    (d / "img").mkdir(parents=True, exist_ok=True)
    (d / "img" / "tiny.png").write_bytes(TINY_PNG)
    (d / "article-gzh.html").write_text(GOOD_TEXT.replace("{IMG}", '<img src="img/tiny.png">'), encoding="utf-8")
    (d / "article-gzh-embedded.html").write_text(
        GOOD_TEXT.replace("{IMG}", f'<img src="data:image/png;base64,{TINY_PNG_B64}">'), encoding="utf-8")


def run(d: pathlib.Path, env_extra=None):
    env = dict(os.environ, GZH_DESIGN_HOME=str(STUB_VALIDATOR))
    if env_extra:
        env.update(env_extra)
    return subprocess.run([sys.executable, str(CHECK), str(d)],
                          capture_output=True, text=True, env=env).returncode


class GateTests(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.d = pathlib.Path(self._tmp.name) / "article"
        self.d.mkdir(parents=True)
        good_pair(self.d)

    def tearDown(self):
        self._tmp.cleanup()

    def test01_good_pair_passes(self):
        self.assertEqual(run(self.d), 0, "正例必须通过（否则测试装置坏了）")

    def test02_missing_img_single_quotes(self):
        p = self.d / "article-gzh.html"
        p.write_text(p.read_text(encoding="utf-8").replace(
            '<img src="img/tiny.png">', "<img src='img/gone.png'>"), encoding="utf-8")
        self.assertEqual(run(self.d), 1, "单引号缺失图片必须拦截")

    def test03_broken_base64_in_embedded(self):
        p = self.d / "article-gzh-embedded.html"
        p.write_text(p.read_text(encoding="utf-8").replace(
            f"data:image/png;base64,{TINY_PNG_B64}", "data:image/png;base64,!!!!"), encoding="utf-8")
        self.assertEqual(run(self.d), 1, "损坏 base64 必须拦截")

    def test04_entity_colon(self):
        p = self.d / "article-gzh.html"
        p.write_text(GOOD_TEXT.replace("{IMG}", '<img src="img/tiny.png">').replace(
            "正文文本", "结论&#xFF1A;就这样"), encoding="utf-8")
        self.assertEqual(run(self.d), 1, "实体冒号必须拦截")

    def test05_body_mismatch(self):
        p = self.d / "article-gzh-embedded.html"
        p.write_text(p.read_text(encoding="utf-8").replace(BODY, BODY + "（内嵌版多出的一句话）"), encoding="utf-8")
        self.assertEqual(run(self.d), 1, "两版正文不同必须拦截")

    def test06_script_tag_in_embedded(self):
        p = self.d / "article-gzh-embedded.html"
        p.write_text(p.read_text(encoding="utf-8") + "<script>alert(1)</script>", encoding="utf-8")
        self.assertEqual(run(self.d), 1, "embedded 版含 script 必须拦截")

    def test07_empty_body(self):
        for name in ("article-gzh.html", "article-gzh-embedded.html"):
            (self.d / name).write_text("<section></section>", encoding="utf-8")
        self.assertEqual(run(self.d), 1, "空正文必须拦截")

    def test08_img_count_mismatch(self):
        p = self.d / "article-gzh-embedded.html"
        p.write_text(p.read_text(encoding="utf-8").replace("</section>",
                      f'<img src="data:image/png;base64,{TINY_PNG_B64}"></section>'), encoding="utf-8")
        self.assertEqual(run(self.d), 1, "图片数量不一致必须拦截（含零图对一图）")

    def test09_validator_missing_fails(self):
        self.assertEqual(run(self.d, {"GZH_DESIGN_HOME": "/nonexistent/validate_gzh_html.py"}), 1,
                         "校验器缺失必须失败，不得跳过后返回 0")

    def test10_placeholder_left(self):
        p = self.d / "article-gzh.html"
        p.write_text(GOOD_TEXT.replace("{IMG}", '<img src="img/tiny.png">').replace(
            BODY, "这是{{产品名}}的占位符残留正文，足够长以通过最小长度检查。"), encoding="utf-8")
        self.assertEqual(run(self.d), 1, "未替换占位符必须拦截")

    def test11_data_uri_in_archive(self):
        p = self.d / "article-gzh.html"
        p.write_text(GOOD_TEXT.replace("{IMG}", f'<img src="data:image/png;base64,{TINY_PNG_B64}">'), encoding="utf-8")
        self.assertEqual(run(self.d), 1, "存档版混入 data: 内嵌必须拦截")

    def test12_img_digest_mismatch(self):
        other = TINY_PNG[:-1] + b"\x00"
        p = self.d / "article-gzh-embedded.html"
        p.write_text(p.read_text(encoding="utf-8").replace(
            TINY_PNG_B64, base64.b64encode(other).decode()), encoding="utf-8")
        self.assertEqual(run(self.d), 1, "同位置图片内容不同必须拦截")


class RealArticleSmoke(unittest.TestCase):
    """本机存在试点文章且装有 gzh-design 时，跑一次真实门禁冒烟。"""

    def setUp(self):
        self.real = pathlib.Path("~/Dev/github/holtwood/wechat-miniprogram/articles/whenfree/"
                                 "2026-10-04-yue-shijian").expanduser()
        self.has_validator = any((pathlib.Path.home() / s / "gzh-design" / "scripts" /
                                  "validate_gzh_html.py").is_file()
                                 for s in (".agents/skills", ".claude/skills"))

    def test_real_article_passes(self):
        if not (self.real.is_dir() and self.has_validator):
            self.skipTest("本机无试点文章或未装 gzh-design")
        self.assertEqual(run(self.real), 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
