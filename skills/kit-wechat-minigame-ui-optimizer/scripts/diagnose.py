#!/usr/bin/env python3
"""对微信小游戏 Canvas UI 做只读基线诊断。"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any, Iterable


SKILL_NAME = "kit-wechat-minigame-ui-optimizer"
IGNORED_DIRS = {".git", "node_modules", "dist", "build", "coverage", "miniprogram_npm", ".cache", "tmp"}
TEST_DIRS = {"test", "tests", "e2e", "__tests__", "fixtures", "mock", "mocks"}
SOURCE_EXTENSIONS = {".js", ".ts", ".jsx", ".tsx", ".json"}
IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp", ".gif", ".svg"}
COLOR_RE = re.compile(r"(?<![\w-])(?:#[0-9a-fA-F]{3,8}\b|rgba?\([^)]*\)|hsla?\([^)]*\))")
DRAW_RE = re.compile(
    r"(?:fillStyle|strokeStyle|font|fillText|strokeText|drawImage|fillRect|strokeRect|arc|clearRect|createImage)", re.I
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(prog=SKILL_NAME, description="只读扫描微信小游戏 Canvas UI 线索。")
    parser.add_argument("project_root", type=Path, help="游戏项目根目录")
    parser.add_argument("--json", action="store_true", dest="as_json", help="输出 JSON")
    parser.add_argument("--out", type=Path, help="将报告写到指定文件")
    return parser.parse_args()


def walk_files(root: Path) -> Iterable[Path]:
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        parts = path.relative_to(root).parts
        if any(part in IGNORED_DIRS for part in parts):
            continue
        yield path


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return ""


def relative(path: Path, root: Path) -> str:
    return path.relative_to(root).as_posix()


def is_test_path(path: Path) -> bool:
    return any(part.lower() in TEST_DIRS for part in path.parts)


def package_scripts(root: Path) -> dict[str, Any]:
    package = root / "package.json"
    if not package.is_file():
        return {"package_json": False, "scripts": {}, "relevant_check_scripts": []}
    try:
        data = json.loads(read_text(package))
    except json.JSONDecodeError:
        data = {}
    scripts = data.get("scripts") if isinstance(data, dict) and isinstance(data.get("scripts"), dict) else {}
    relevant = sorted(name for name in scripts if re.search(r"test|check|lint|type|audit|e2e|guard", name, re.I))
    return {
        "package_json": True,
        "scripts": {name: scripts[name] for name in sorted(scripts)},
        "relevant_check_scripts": relevant,
    }


def build_report(root: Path) -> dict[str, Any]:
    files = list(walk_files(root))
    source_files = [path for path in files if path.suffix.lower() in SOURCE_EXTENSIONS and not is_test_path(path)]
    color_files: list[dict[str, Any]] = []
    draw_files: list[dict[str, Any]] = []
    draw_hits = 0
    color_hits = 0
    for path in source_files:
        text = read_text(path)
        colors = COLOR_RE.findall(text)
        draws = DRAW_RE.findall(text)
        color_hits += len(colors)
        draw_hits += len(draws)
        rel = relative(path, root)
        if colors:
            color_files.append({"file": rel, "count": len(colors)})
        if draws:
            draw_files.append({"file": rel, "count": len(draws)})
    color_files.sort(key=lambda item: (-item["count"], item["file"]))
    draw_files.sort(key=lambda item: (-item["count"], item["file"]))
    images = [path for path in files if path.suffix.lower() in IMAGE_EXTENSIONS]
    image_bytes = sum(path.stat().st_size for path in images if path.exists())
    entry_files = [
        relative(path, root)
        for path in files
        if path.name.lower() in {"game.json", "game.js", "game.ts", "app.js", "app.ts"}
    ]
    has_game_entry = any(path.name in {"game.json", "game.js"} for path in files)
    warnings: list[str] = []
    if not has_game_entry:
        warnings.append("未发现 game.json/game.js，需人工确认这是不是微信小游戏项目")
    if not draw_files:
        warnings.append("未找到常见 Canvas 绘制 API，可能需要从自定义渲染封装继续追踪")
    if color_hits:
        warnings.append("发现候选硬编码颜色；Canvas 颜色需要结合设计规范和游戏状态复核")
    return {
        "skill": SKILL_NAME,
        "project_root": str(root),
        "project_type": "微信小游戏（Canvas）" if has_game_entry else "未确认",
        "entry_files": sorted(set(entry_files)),
        "source_file_count": len(source_files),
        "canvas_draw_keyword_occurrences": draw_hits,
        "files_with_canvas_draw_keywords": draw_files[:30],
        "candidate_hardcoded_color_occurrences": color_hits,
        "files_with_candidate_colors": color_files[:30],
        "image_files": len(images),
        "image_bytes": image_bytes,
        "package": package_scripts(root),
        "warnings": warnings,
    }


def human_report(report: dict[str, Any]) -> str:
    package = report["package"]
    lines = [
        f"项目：{report['project_root']}",
        f"形态：{report['project_type']}",
        f"入口：{', '.join(report['entry_files']) or '未发现'}",
        f"源码：{report['source_file_count']} 个，Canvas 绘制线索：{report['canvas_draw_keyword_occurrences']} 处",
        f"候选硬编码颜色：{report['candidate_hardcoded_color_occurrences']} 处",
        f"图片资源：{report['image_files']} 个，{report['image_bytes']} bytes",
        f"可用检查脚本：{', '.join(package['relevant_check_scripts']) or '未发现'}",
    ]
    if report["files_with_canvas_draw_keywords"]:
        lines.append("绘制线索文件：")
        lines.extend(
            f"  - {item['file']} ({item['count']} 处)"
            for item in report["files_with_canvas_draw_keywords"][:12]
        )
    if report["warnings"]:
        lines.append("需要人工复核：")
        lines.extend(f"  - {warning}" for warning in report["warnings"])
    else:
        lines.append("静态基线：未发现额外提示；仍需模拟器/真机截图验收。")
    return "\n".join(lines)


def main() -> int:
    args = parse_args()
    root = args.project_root.expanduser().resolve()
    if not root.is_dir():
        print(f"错误：游戏目录不存在或不是目录：{root}", file=sys.stderr)
        return 2
    report = build_report(root)
    output = json.dumps(report, ensure_ascii=False, indent=2) if args.as_json else human_report(report)
    if args.out:
        destination = args.out.expanduser().resolve()
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(output + "\n", encoding="utf-8")
        print(f"报告已写入：{destination}")
    else:
        print(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
