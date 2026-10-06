#!/usr/bin/env python3
"""prose_lint.py 回归用例：指纹命中、豁免语境、句首复读、句长统计。"""
import pathlib
import subprocess
import sys
import tempfile
import unittest

SCRIPT = pathlib.Path(__file__).resolve().parent.parent / "scripts" / "prose_lint.py"


class ProseLintTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.md = pathlib.Path(self.tmp.name) / "article.md"

    def run_lint(self, *args):
        return subprocess.run(
            [sys.executable, str(SCRIPT), str(self.md), *args],
            capture_output=True, text=True)

    def write(self, text):
        self.md.write_text(text, encoding="utf-8")

    def test_clean_text_no_findings(self):
        self.write("水果是软的。挤压、变形、缓缓流动，蜜桃被邻居挤着压出一圈褶。\n")
        r = self.run_lint()
        self.assertEqual(r.returncode, 0)
        self.assertIn("无文风指纹命中", r.stdout)

    def test_banned_patterns_reported_but_not_fatal(self):
        self.write("这里有个经典坑。值得注意的是，这个方案赋能了效率提升。\n")
        r = self.run_lint()
        self.assertEqual(r.returncode, 0)  # 默认只提示
        self.assertIn("铺垫句式", r.stdout)
        self.assertIn("翻译腔", r.stdout)
        self.assertIn("互联网黑话", r.stdout)

    def test_strict_mode_fails_on_findings(self):
        self.write("这里有个坑。\n")
        r = self.run_lint("--strict")
        self.assertEqual(r.returncode, 1)

    def test_legit_context_still_passes(self):
        # 词表命中只是复查线索：合法语境里的「闭环」会报告但不判失败
        self.write("控制器使用闭环反馈调整输出。心理学家用老鼠来做试验。\n")
        r = self.run_lint()
        self.assertEqual(r.returncode, 0)
        self.assertIn("互联网黑话", r.stdout)

    def test_opener_run_detected(self):
        self.write("我们要保证质量。我们要控制成本。我们要按时交付。\n")
        r = self.run_lint()
        self.assertIn("句首复读", r.stdout)

    def test_burstiness_stats_present(self):
        self.write("短。长一点的句子在这里继续走下去。\n" * 10)
        r = self.run_lint("--json")
        self.assertIn('"cv"', r.stdout)

    def test_dict_extends_patterns(self):
        self.write("这个功能绝绝子。\n")
        dictfile = pathlib.Path(self.tmp.name) / "dict.txt"
        dictfile.write_text("绝绝子\t网络热词\t删\n", encoding="utf-8")
        r = self.run_lint("--dict", str(dictfile))
        self.assertIn("网络热词", r.stdout)

    def test_headings_and_code_skipped(self):
        self.write("# 这里有个标题\n```\n这里有个代码\n```\n正文正常一句话。\n")
        r = self.run_lint()
        self.assertNotIn("铺垫句式", r.stdout)

    def test_vague_quantifier_without_number(self):
        # 「大幅提升」「明显改善」这类没数字撑的量化主张是 AI 虚胖句式
        self.write("优化后加载速度大幅提升。小屏直径约增加 12%。\n")
        r = self.run_lint()
        self.assertEqual(r.returncode, 0)  # 仍是线索不判失败
        self.assertIn("虚胖量化", r.stdout)
        self.assertEqual(r.stdout.count("虚胖量化"), 1)  # 带数字那句不误报

    def test_vague_quantifier_with_chinese_number_ok(self):
        self.write("明显比上一版多了一个步骤。\n")
        r = self.run_lint()
        self.assertNotIn("虚胖量化", r.stdout)

    def test_xing_noun_density(self):
        # 「X性」名词化是中文实证里的 AI 指纹，按密度报不按单处报
        self.write("方案的稳定性和适用性都不错，安全性和依赖性也过关，可用性另说。\n")
        r = self.run_lint()
        self.assertEqual(r.returncode, 0)
        self.assertIn("抽象名词化", r.stdout)

    def test_connector_stacking(self):
        self.write("此外这个方法更快。因此我们采用了它。同时文档也更新了。总的来说体验更好。\n")
        r = self.run_lint()
        self.assertIn("过渡词堆叠", r.stdout)

    def test_connector_under_threshold_ok(self):
        self.write("此外这个方法更快。测试通过了。\n")
        r = self.run_lint()
        self.assertNotIn("过渡词堆叠", r.stdout)

    def test_region_words_in_simplified_text(self):
        self.write("这个软体跑在伺服器上，介面还算顺手。\n")
        r = self.run_lint()
        self.assertIn("地区词混用", r.stdout)

    def test_chengsihi_false_positive_guard(self):
        # 「程式化」是合法简中词，不算台湾「程式」
        self.write("流程已经很程式化了。\n")
        r = self.run_lint()
        self.assertNotIn("地区词混用", r.stdout)

    def test_traditional_chars_mixed(self):
        self.write("这个功能很實用，體驗也好。\n")
        r = self.run_lint()
        self.assertIn("简繁混用", r.stdout)

    def test_ai_meta_leak(self):
        self.write("作为一个人工智能，我的训练数据截至我的知识更新为止。\n")
        r = self.run_lint()
        self.assertIn("AI 元话语", r.stdout)

    def test_era_opener_and_meta_narration(self):
        self.write("随着人工智能技术的飞速发展，开发者越来越忙。本文将介绍一个小工具。\n")
        r = self.run_lint()
        self.assertIn("时代开场", r.stdout)
        self.assertIn("元叙述", r.stdout)

    def test_hype_and_ad_law_words(self):
        self.write("这是一个革命性的工具，效果 100% 保证，全网第一。\n")
        r = self.run_lint()
        self.assertEqual(r.returncode, 0)
        self.assertIn("夸大词", r.stdout)
        self.assertIn("广告法风险", r.stdout)

    def test_plain_development_sentence_not_era_opener(self):
        self.write("项目发展到第二版时，我把导出功能拆了出来。\n")
        r = self.run_lint()
        self.assertNotIn("时代开场", r.stdout)


if __name__ == "__main__":
    unittest.main()
