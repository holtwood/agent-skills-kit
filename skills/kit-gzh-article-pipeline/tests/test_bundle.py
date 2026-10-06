#!/usr/bin/env python3
"""Regressions for article preservation, scoped delivery and frontmatter export."""
from __future__ import annotations

import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent.parent / "scripts/article_bundle.py"
SPEC = importlib.util.spec_from_file_location("article_bundle", SCRIPT)
BUNDLE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BUNDLE)


class BundleTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve() / "post"
        BUNDLE.initialize(self.root, "demo-post", list(BUNDLE.PLATFORMS))
        self.data = BUNDLE.load_bundle(self.root)
        self.body = "## 示例\n\n仅支持 CSV。尚未测试知乎保存。\n\n![演示](img/sample.png)\n\n```js\nconst count = 10;\n```\n"
        (self.root / "article.md").write_text(self.body, encoding="utf-8")
        for name, target in self.data["platforms"].items():
            target.update(title="教学示例", summary="展示操作与当前限制。")
            (self.root / target["draft"]).write_text(self.body, encoding="utf-8")
        (self.root / "img/sample.png").write_bytes(b"fixture, not a real screenshot")
        self.data["assets"] = [{"path": "img/sample.png", "source": "test fixture"}]
        self.data["facts"] = [{"id": "F1", "statement": "仅支持 CSV", "source": "test fixture"}]
        self.data["must_keep"] = [{"text": "仅支持 CSV"}]
        self.save()

    def save(self):
        (self.root / "bundle.json").write_text(json.dumps(self.data, ensure_ascii=False), encoding="utf-8")

    def cli(self, *args):
        result = subprocess.run([sys.executable, str(SCRIPT), *args, str(self.root), "--json"],
                                capture_output=True, text=True, encoding="utf-8")
        return result.returncode, json.loads(result.stdout)

    def test_scoped_init_and_unfinished_scaffold(self):
        root = self.root.parent / "astro-only"
        BUNDLE.initialize(root, "astro-only", ["astro"])
        data = BUNDLE.load_bundle(root)
        self.assertEqual(set(data["platforms"]), {"astro"})
        self.assertFalse((root / "article-wechat.md").exists())
        self.assertTrue(any("尚未完成正文" in error for error in BUNDLE.check(root, data, ["astro"])))

    def test_existing_file_prevents_all_init_writes(self):
        root = self.root.parent / "existing"
        root.mkdir()
        (root / "article-zhihu.md").write_text("author original", encoding="utf-8")
        with self.assertRaises(ValueError):
            BUNDLE.initialize(root, "existing", ["astro", "zhihu"])
        self.assertEqual([path.name for path in root.iterdir()], ["article-zhihu.md"])

    def test_local_check_reports_limited_scope_and_no_publication(self):
        code, result = self.cli("check")
        self.assertEqual(code, 0)
        self.assertTrue(result["ok"])
        self.assertEqual(result["publication"], "not-attempted")
        self.assertIn("只检查清单声明的素材", result["limitations"])

    def test_partial_platform_does_not_require_other_finished_drafts(self):
        (self.root / "article-toutiao.md").write_text(BUNDLE.SCAFFOLD, encoding="utf-8")
        self.assertTrue(BUNDLE.check(self.root, self.data, list(BUNDLE.PLATFORMS)))
        self.assertEqual(BUNDLE.check(self.root, self.data, ["astro"]), [])
        self.assertTrue(Path(BUNDLE.export_astro(self.root, self.data, "article-astro.md")).exists())

    def test_preserved_restriction_detects_platform_loss(self):
        (self.root / "article-zhihu.md").write_text("已经支持所有格式。", encoding="utf-8")
        errors = BUNDLE.check(self.root, self.data, ["astro", "zhihu"])
        self.assertTrue(any("zhihu: 缺少" in error for error in errors))
        self.assertFalse(any("astro: 缺少" in error for error in errors))

    def test_fact_source_and_unique_ids_required(self):
        self.data["facts"] += [{"id": "F2", "statement": "example", "source": ""},
                               {"id": "F1", "statement": "example", "source": "fixture"}]
        errors = BUNDLE.check(self.root, self.data, ["astro"])
        self.assertTrue(any("F2.source" in error for error in errors))
        self.assertTrue(any("fact.id 重复" in error for error in errors))

    def test_missing_asset_fails(self):
        (self.root / "img/sample.png").unlink()
        self.assertTrue(any("素材缺失" in error for error in BUNDLE.check(self.root, self.data, ["astro"])))

    def test_traversal_and_absolute_paths_rejected(self):
        for path in ("../outside.md", str(self.root.parent / "outside.md"), "."):
            with self.subTest(path=path), self.assertRaises(ValueError):
                BUNDLE.local_path(self.root, path)

    @unittest.skipIf(os.name == "nt", "POSIX symlink fixture")
    def test_symlink_escape_and_dangling_destination_rejected(self):
        (self.root / "outside").symlink_to(self.root.parent)
        with self.assertRaises(ValueError):
            BUNDLE.local_path(self.root, "outside/file.md")
        output = self.root / "dangling.md"
        output.symlink_to(self.root / "missing.md")
        with self.assertRaises(ValueError):
            BUNDLE.export_astro(self.root, self.data, "dangling.md")
        self.assertFalse((self.root / "missing.md").exists())

    def test_independent_drafts_and_reserved_platform_id(self):
        self.data["platforms"]["astro"]["draft"] = "article.md"
        self.save()
        with self.assertRaises(ValueError):
            BUNDLE.load_bundle(self.root)
        self.data["platforms"] = {"master": {"draft": "other.md"}}
        self.save()
        with self.assertRaises(ValueError):
            BUNDLE.load_bundle(self.root)

    def test_astro_preserves_body_and_metadata_types(self):
        metadata = {"title": "标题：含引号\"与换行\n下一行", "publishedAt": "2026-10-05",
                    "tags": ["Astro", "中文"], "draft": True, "priority": 2}
        self.data["platforms"]["astro"]["frontmatter"] = metadata
        result = Path(BUNDLE.export_astro(self.root, self.data, "article-astro.md")).read_text(encoding="utf-8")
        header, body = result[4:].split("\n---\n\n", 1)
        decoded = {key: json.loads(value) for key, value in (line.split(": ", 1) for line in header.splitlines())}
        self.assertEqual(decoded, metadata)
        self.assertEqual(body, self.body)
        self.assertNotIn("description:", header)

    def test_astro_existing_output_and_body_frontmatter_protected(self):
        (self.root / "article-astro.md").write_text("author output", encoding="utf-8")
        with self.assertRaises(ValueError):
            BUNDLE.export_astro(self.root, self.data, "article-astro.md")
        self.assertEqual((self.root / "article-astro.md").read_text(encoding="utf-8"), "author output")
        (self.root / "article-astro-body.md").write_text("---\ntitle: author\n---\n" + self.body, encoding="utf-8")
        with self.assertRaises(ValueError):
            BUNDLE.export_astro(self.root, self.data, "new.md")
        self.assertFalse((self.root / "new.md").exists())

    def test_astro_relative_image_base_and_unknown_target_protected(self):
        with self.assertRaises(ValueError):
            BUNDLE.export_astro(self.root, self.data, "elsewhere/new.md")
        with self.assertRaises(ValueError):
            BUNDLE.check(self.root, self.data, ["missing-platform"])


if __name__ == "__main__":
    unittest.main()
