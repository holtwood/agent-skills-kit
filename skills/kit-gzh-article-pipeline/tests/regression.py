#!/usr/bin/env python3
"""regression.py — kit-gzh-article-pipeline 两个脚本的假通过反例回归测试。

用法:
    python3 tests/regression.py          # 全部反例 + 正例
    python3 tests/regression.py -v       # 详细输出

构成（反例来自三轮外部评审的实测发现，改任一脚本后必须全绿）:
  - GateTests: 终检 check_article.py 的反例，用 stub 校验器隔离被测逻辑
  - CoverTests: render_cover.sh 的反例与正例（需要 Chrome，缺失自动跳过）
  - ValidatorInterfaceTests: 校验器警告拦截（exit 0 但输出 ⚠️ 也算失败）
  - RealArticleSmoke: 真实文章 + 真实 gzh-design 校验器的对接冒烟（无 stub）
"""
import base64
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
import unittest

SKILL = pathlib.Path(__file__).resolve().parent.parent
CHECK = SKILL / "scripts" / "check_article.py"
COVER = SKILL / "scripts" / "render_cover.sh"
FIXTURES = SKILL / "tests" / "fixtures"
STUB_OK = FIXTURES / "stub_validator.py"
STUB_WARN = FIXTURES / "stub_warning_validator.py"

# 1x1 透明 PNG
TINY_PNG = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==")
TINY_PNG_B64 = base64.b64encode(TINY_PNG).decode()
BODY = ("大家好，这是一段足够长的可见正文文本，用来通过终检的最小长度检查。"
        "正文里没有任何禁用标点与占位符，两份产物保持逐字一致。")
GOOD_TEXT = f"<section><p><span leaf=\"\">{BODY}</span></p>{{IMG}}</section>"

REAL_ARTICLE = os.environ.get("GZH_ARTICLE_SMOKE_DIR")


def locate_real_validator():
    for s in (".agents/skills", ".claude/skills"):
        p = pathlib.Path.home() / s / "gzh-design" / "scripts" / "validate_gzh_html.py"
        if p.is_file():
            return p
    return None


def find_chrome():
    if os.environ.get("KIT_SKIP_BROWSER_TESTS") == "1":
        return None
    candidates = [os.environ.get("CHROME_BIN"),
                  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
                  "/Applications/Chromium.app/Contents/MacOS/Chromium",
                  shutil.which("chromium"), shutil.which("google-chrome")]
    for c in candidates:
        if c and pathlib.Path(c).is_file():
            return c
    return None


def make_good_pair(d: pathlib.Path, img_name="img/tiny.png"):
    (d / "img").mkdir(parents=True, exist_ok=True)
    (d / img_name).parent.mkdir(parents=True, exist_ok=True)
    (d / img_name).write_bytes(TINY_PNG)
    (d / "article-gzh.html").write_text(
        GOOD_TEXT.replace("{IMG}", f'<img src="{img_name}">'), encoding="utf-8")
    (d / "article-gzh-embedded.html").write_text(
        GOOD_TEXT.replace("{IMG}", f'<img src="data:image/png;base64,{TINY_PNG_B64}">'), encoding="utf-8")


def run_check(d: pathlib.Path, validator=STUB_OK) -> int:
    """validator=None 时不设置 GZH_DESIGN_HOME，让脚本自动定位真实校验器。"""
    env = dict(os.environ)
    if validator is None:
        env.pop("GZH_DESIGN_HOME", None)
    else:
        env["GZH_DESIGN_HOME"] = str(validator)
    return subprocess.run([sys.executable, str(CHECK), str(d), "--text-policy", "legacy"],
                          capture_output=True, text=True, env=env).returncode


def run_cover(d: pathlib.Path) -> int:
    return subprocess.run(["bash", str(COVER), str(d)], capture_output=True, text=True).returncode


class GateTests(unittest.TestCase):
    """终检脚本反例（stub 校验器隔离）。"""

    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.d = pathlib.Path(self._tmp.name) / "article"
        self.d.mkdir(parents=True)
        make_good_pair(self.d)

    def tearDown(self):
        self._tmp.cleanup()

    def test01_good_pair_passes(self):
        self.assertEqual(run_check(self.d), 0, "正例必须通过（否则测试装置坏了）")

    def test02_missing_img_single_quotes(self):
        p = self.d / "article-gzh.html"
        p.write_text(p.read_text(encoding="utf-8").replace(
            '<img src="img/tiny.png">', "<img src='img/gone.png'>"), encoding="utf-8")
        self.assertEqual(run_check(self.d), 1, "单引号缺失图片必须拦截")

    def test03_broken_base64_in_embedded(self):
        p = self.d / "article-gzh-embedded.html"
        p.write_text(p.read_text(encoding="utf-8").replace(
            f"data:image/png;base64,{TINY_PNG_B64}", "data:image/png;base64,!!!!"), encoding="utf-8")
        self.assertEqual(run_check(self.d), 1, "损坏 base64 必须拦截")

    def test04_entity_colon(self):
        p = self.d / "article-gzh.html"
        p.write_text(GOOD_TEXT.replace("{IMG}", '<img src="img/tiny.png">').replace(
            "正文文本", "结论&#xFF1A;就这样"), encoding="utf-8")
        self.assertEqual(run_check(self.d), 1, "实体冒号必须拦截")

    def test05_body_mismatch(self):
        p = self.d / "article-gzh-embedded.html"
        p.write_text(p.read_text(encoding="utf-8").replace(BODY, BODY + "（内嵌版多出的一句话）"), encoding="utf-8")
        self.assertEqual(run_check(self.d), 1, "两版正文不同必须拦截")

    def test06_script_tag_in_embedded(self):
        p = self.d / "article-gzh-embedded.html"
        p.write_text(p.read_text(encoding="utf-8") + "<script>alert(1)</script>", encoding="utf-8")
        self.assertEqual(run_check(self.d), 1, "embedded 版含 script 必须拦截")

    def test07_empty_body(self):
        for name in ("article-gzh.html", "article-gzh-embedded.html"):
            (self.d / name).write_text("<section></section>", encoding="utf-8")
        self.assertEqual(run_check(self.d), 1, "空正文必须拦截")

    def test08_img_count_mismatch(self):
        p = self.d / "article-gzh-embedded.html"
        p.write_text(p.read_text(encoding="utf-8").replace("</section>",
                      f'<img src="data:image/png;base64,{TINY_PNG_B64}"></section>'), encoding="utf-8")
        self.assertEqual(run_check(self.d), 1, "图片数量不一致必须拦截（含零图对一图）")

    def test09_validator_missing_fails(self):
        self.assertEqual(run_check(self.d, validator="/nonexistent/validate_gzh_html.py"), 1,
                         "校验器缺失必须失败，不得跳过后返回 0")

    def test10_placeholder_left(self):
        p = self.d / "article-gzh.html"
        p.write_text(GOOD_TEXT.replace("{IMG}", '<img src="img/tiny.png">').replace(
            BODY, "这是{{产品名}}的占位符残留正文，足够长以通过最小长度检查。"), encoding="utf-8")
        self.assertEqual(run_check(self.d), 1, "未替换占位符必须拦截")

    def test11_data_uri_in_archive(self):
        p = self.d / "article-gzh.html"
        p.write_text(GOOD_TEXT.replace("{IMG}", f'<img src="data:image/png;base64,{TINY_PNG_B64}">'), encoding="utf-8")
        self.assertEqual(run_check(self.d), 1, "存档版混入 data: 内嵌必须拦截")

    def test12_img_digest_mismatch(self):
        other = TINY_PNG[:-1] + b"\x00"
        p = self.d / "article-gzh-embedded.html"
        p.write_text(p.read_text(encoding="utf-8").replace(
            TINY_PNG_B64, base64.b64encode(other).decode()), encoding="utf-8")
        self.assertEqual(run_check(self.d), 1, "同位置图片内容不同必须拦截")

    # ---- 第三轮：data URI 与真实解码 ----

    def test13_data_uri_without_base64_marker(self):
        p = self.d / "article-gzh-embedded.html"
        p.write_text(p.read_text(encoding="utf-8").replace(
            f"data:image/png;base64,{TINY_PNG_B64}", f"data:image/png,{TINY_PNG_B64}"), encoding="utf-8")
        self.assertEqual(run_check(self.d), 1, "缺 ;base64 标记的 data URI 必须拦截")

    def test14_fake_four_byte_png(self):
        fake = b"\x89PNG"
        (self.d / "img" / "tiny.png").write_bytes(fake)
        p = self.d / "article-gzh-embedded.html"
        p.write_text(GOOD_TEXT.replace("{IMG}", f'<img src="data:image/png;base64,{base64.b64encode(fake).decode()}">'),
                     encoding="utf-8")
        self.assertEqual(run_check(self.d), 1, "四字节假 PNG（本地与内嵌）必须拦截")

    def test15_riff_disguised_as_png(self):
        riff = b"RIFF" + b"\x00" * 200  # WAV/WEBP 家族魔数伪装
        (self.d / "img" / "tiny.png").write_bytes(riff)
        p = self.d / "article-gzh-embedded.html"
        p.write_text(GOOD_TEXT.replace("{IMG}", f'<img src="data:image/png;base64,{base64.b64encode(riff).decode()}">'),
                     encoding="utf-8")
        self.assertEqual(run_check(self.d), 1, "RIFF 伪装 PNG 必须拦截")


    def test_standard_policy_allows_normal_punctuation(self):
        for name in ("article-gzh.html", "article-gzh-embedded.html"):
            p = self.d / name
            p.write_text(p.read_text(encoding="utf-8").replace(BODY, BODY + "功能：记录——完成。"), encoding="utf-8")
        proc = subprocess.run([sys.executable, str(CHECK), str(self.d), "--json"],
                              capture_output=True, text=True,
                              env={**os.environ, "GZH_DESIGN_HOME": str(STUB_OK)})
        import json
        result = json.loads(proc.stdout)
        self.assertEqual(proc.returncode, 0, proc.stdout)
        self.assertTrue(result["ok"])

    def test_url_encoded_local_image(self):
        (self.d / "img/tiny.png").rename(self.d / "img/a b.png")
        p = self.d / "article-gzh.html"
        p.write_text(p.read_text(encoding="utf-8").replace("img/tiny.png", "img/a%20b.png"), encoding="utf-8")
        self.assertEqual(run_check(self.d), 0)

    def test_external_validator_timeout_fails(self):
        validator = self.d / "slow.py"
        validator.write_text("import time; time.sleep(5)\n", encoding="utf-8")
        proc = subprocess.run([sys.executable, str(CHECK), str(self.d), "--json", "--validator-timeout", "0.1"],
                              capture_output=True, text=True, timeout=3,
                              env={**os.environ, "GZH_DESIGN_HOME": str(validator)})
        import json
        self.assertEqual(proc.returncode, 1)
        self.assertTrue(any("TimeoutExpired" in f for f in json.loads(proc.stdout)["findings"]))


class ValidatorInterfaceTests(unittest.TestCase):
    """校验器退出码为 0 但输出警告 → 门禁必须失败（防警告拦截回退）。"""

    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.d = pathlib.Path(self._tmp.name) / "article"
        self.d.mkdir(parents=True)
        make_good_pair(self.d)

    def tearDown(self):
        self._tmp.cleanup()

    def test16_warning_still_fails(self):
        self.assertEqual(run_check(self.d, validator=STUB_WARN), 1, "校验器输出警告（退出码 0）必须判失败")


class CoverTests(unittest.TestCase):
    """render_cover.sh 反例与正例（需要 Chrome）。"""

    def setUp(self):
        if not find_chrome():
            self.skipTest("本机未找到 Chrome/Chromium")
        self._tmp = tempfile.TemporaryDirectory()
        self.d = pathlib.Path(self._tmp.name) / "article"
        self.d.mkdir(parents=True)
        (self.d / "img").mkdir(parents=True)
        for name in ("img/01-home.png", "img/02-home-b.png"):
            (self.d / name).write_bytes(TINY_PNG)
        tpl = (SKILL / "assets" / "cover.html").read_text(encoding="utf-8")
        self.template = tpl

    def tearDown(self):
        self._tmp.cleanup()

    def _fill(self, text):
        for k, v in {"主色": "#07c160", "主色深": "#06ad56", "主色更深": "#05934f",
                     "浅色文字": "#d4f7e2", "更浅文字": "#eafff3", "顶部标签": "微信小程序",
                     "产品名": "测试产品", "一句话主张": "一句话主张", "能力1": "甲", "能力2": "乙",
                     "能力3": "丙"}.items():
            text = text.replace("{{%s}}" % k, v)
        return text

    def test17_valid_cover_renders(self):
        (self.d / "cover.html").write_text(self._fill(self.template), encoding="utf-8")
        result = subprocess.run(["bash", str(COVER), str(self.d)], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test18_height_566_fails(self):
        t = self._fill(self.template).replace("width: 1800px; height: 766px", "width: 1800px; height: 566px")
        (self.d / "cover.html").write_text(t, encoding="utf-8")
        self.assertEqual(run_cover(self.d), 1, "头图区块高度偏离模板必须拦截")

    def test19_css_placeholder_fails(self):
        # 其余全填好，只留样式里的 {{主色}} —— innerText 看不到，源码扫描必须抓到
        t = self._fill(self.template).replace("#07c160", "{{主色}}", 1)
        (self.d / "cover.html").write_text(t, encoding="utf-8")
        self.assertEqual(run_cover(self.d), 1, "样式里的占位符必须拦截")


class RealArticleSmoke(unittest.TestCase):
    """真实文章 + 真实 gzh-design 校验器（无 stub），验证对接。"""

    def test_real_article_passes(self):
        validator = locate_real_validator()
        if not (REAL_ARTICLE and pathlib.Path(REAL_ARTICLE).expanduser().is_dir() and validator):
            self.skipTest("未设置 GZH_ARTICLE_SMOKE_DIR 或未装 gzh-design")
        # 显式传真实校验器所在目录（目录形式，顺带验证 GZH_DESIGN_HOME 目录解析）
        env_validator = str(validator.parent.parent)
        self.assertEqual(run_check(pathlib.Path(REAL_ARTICLE).expanduser(), validator=env_validator), 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
