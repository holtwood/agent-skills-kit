#!/usr/bin/env python3
"""对微信原生小程序或混合小程序做只读 UI 基线诊断。"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any, Iterable


SKILL_NAME = "kit-wechat-miniapp-ui-optimizer"
IGNORED_DIRS = {
    ".git",
    "node_modules",
    "dist",
    "build",
    "coverage",
    "miniprogram_npm",
    ".next",
    ".cache",
    "tmp",
    "test-results",
}
TEST_DIRS = {"test", "tests", "e2e", "__tests__", "fixtures", "mock", "mocks"}
UI_EXTENSIONS = {".wxml", ".wxss", ".css", ".scss", ".less", ".js", ".jsx", ".ts", ".tsx"}
IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp", ".gif", ".svg"}
COLOR_RE = re.compile(
    r"(?<![\w-])(?:#[0-9a-fA-F]{3,8}\b|rgba?\([^)]*\)|hsla?\([^)]*\))"
)
TOKEN_RE = re.compile(r"(?:var\s*\(--[\w-]+\)|--[\w-]+|theme|token|design-system)", re.I)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog=SKILL_NAME,
        description="只读扫描微信小程序的 UI 结构、样式线索和检查入口。",
    )
    parser.add_argument("project_root", type=Path, help="项目根目录")
    parser.add_argument("--json", action="store_true", dest="as_json", help="输出 JSON")
    parser.add_argument("--out", type=Path, help="将报告写到指定文件")
    return parser.parse_args()


def walk_files(root: Path) -> Iterable[Path]:
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        try:
            relative_parts = path.relative_to(root).parts
        except ValueError:
            continue
        if any(part in IGNORED_DIRS for part in relative_parts):
            continue
        yield path


def is_test_path(path: Path) -> bool:
    return any(part.lower() in TEST_DIRS for part in path.parts)


def relative(path: Path, root: Path) -> str:
    return path.relative_to(root).as_posix()


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return ""


def load_json(path: Path) -> dict[str, Any] | None:
    if not path.is_file():
        return None
    try:
        value = json.loads(read_text(path))
    except json.JSONDecodeError:
        return None
    return value if isinstance(value, dict) else None


def detect_type(root: Path, files: list[Path]) -> tuple[str, list[str]]:
    names = {path.name for path in files}
    has_miniprogram = (root / "miniprogram").is_dir() or any(path.suffix == ".wxml" for path in files)
    has_src = (root / "src").is_dir()
    has_game = "game.json" in names or "game.js" in names
    signals: list[str] = []
    if has_game and not has_miniprogram:
        return "疑似微信小游戏（请改用 kit-wechat-minigame-ui-optimizer）", ["发现 game.json/game.js，不套用 WXML/WXSS 规则"]
    if has_miniprogram:
        signals.append("发现 miniprogram 或 WXML/WXSS，按微信原生页面规则审查")
    if has_src and has_miniprogram:
        return "混合项目（Web + 微信小程序）", signals + ["同时发现 src/ 与小程序目录，需区分两个端的样式边界"]
    if has_miniprogram:
        return "微信原生小程序", signals
    if has_src:
        return "可能是 Web/混合项目", signals + ["未发现明确的小程序入口，请人工确认构建方式"]
    return "未识别", signals + ["未发现常见微信小程序入口"]


def find_token_candidates(root: Path, files: list[Path]) -> list[str]:
    candidates: list[str] = []
    for path in files:
        rel = relative(path, root)
        lowered = rel.lower()
        if any(term in lowered for term in ("token", "theme", "variable", "design-system", "global", "common")):
            candidates.append(rel)
            continue
        if path.name.lower() in {"app.wxss", "app.scss", "app.css", "variables.css", "variables.scss"}:
            candidates.append(rel)
    return sorted(set(candidates))[:40]


def find_pages(root: Path, files: list[Path]) -> tuple[list[str], list[str]]:
    pages: list[str] = []
    components: list[str] = []
    for path in files:
        rel = relative(path, root)
        parts = [part.lower() for part in path.relative_to(root).parts]
        if path.suffix == ".wxml" and "pages" in parts:
            pages.append(rel)
        if path.suffix == ".wxml" and "components" in parts:
            components.append(rel)
    return sorted(pages), sorted(components)


def source_metrics(root: Path, files: list[Path]) -> dict[str, Any]:
    production_files = [path for path in files if path.suffix.lower() in UI_EXTENSIONS and not is_test_path(path)]
    color_hits: list[dict[str, Any]] = []
    token_hits = 0
    by_extension: dict[str, int] = {}
    for path in production_files:
        extension = path.suffix.lower()
        by_extension[extension] = by_extension.get(extension, 0) + 1
        text = read_text(path)
        token_hits += len(TOKEN_RE.findall(text))
        matches = COLOR_RE.findall(text)
        if matches:
            color_hits.append({"file": relative(path, root), "count": len(matches)})
    color_hits.sort(key=lambda item: (-item["count"], item["file"]))
    return {
        "ui_source_files": len(production_files),
        "ui_source_by_extension": dict(sorted(by_extension.items())),
        "candidate_hardcoded_color_occurrences": sum(item["count"] for item in color_hits),
        "files_with_candidate_colors": color_hits[:30],
        "token_keyword_occurrences": token_hits,
    }


def image_metrics(root: Path, files: list[Path]) -> dict[str, Any]:
    images = [path for path in files if path.suffix.lower() in IMAGE_EXTENSIONS]
    total_bytes = 0
    for path in images:
        try:
            total_bytes += path.stat().st_size
        except OSError:
            pass
    return {"image_files": len(images), "image_bytes": total_bytes}


def package_metrics(root: Path) -> dict[str, Any]:
    package = load_json(root / "package.json") or {}
    scripts = package.get("scripts") if isinstance(package.get("scripts"), dict) else {}
    relevant = sorted(
        name for name in scripts if re.search(r"test|check|lint|type|audit|contrast|e2e|guard", name, re.I)
    )
    return {
        "package_json": (root / "package.json").is_file(),
        "scripts": {name: scripts[name] for name in sorted(scripts)},
        "relevant_check_scripts": relevant,
    }


def build_report(root: Path) -> dict[str, Any]:
    files = list(walk_files(root))
    project_type, signals = detect_type(root, files)
    pages, components = find_pages(root, files)
    metrics = source_metrics(root, files)
    token_candidates = find_token_candidates(root, files)
    report: dict[str, Any] = {
        "skill": SKILL_NAME,
        "project_root": str(root),
        "project_type": project_type,
        "signals": signals,
        "entry_files": {
            "project_config": (root / "project.config.json").is_file(),
            "app_json": (root / "app.json").is_file() or (root / "miniprogram" / "app.json").is_file(),
            "game_json": (root / "game.json").is_file(),
            "game_js": (root / "game.js").is_file(),
        },
        "pages": pages[:100],
        "page_count": len(pages),
        "components": components[:100],
        "component_count": len(components),
        "token_candidates": token_candidates,
        "token_candidate_count": len(token_candidates),
        "source_metrics": metrics,
        "image_metrics": image_metrics(root, files),
        "package": package_metrics(root),
    }
    warnings: list[str] = []
    if not token_candidates:
        warnings.append("未找到明显的 token/theme/global 样式权威文件，需要人工确认视觉规范")
    if metrics["candidate_hardcoded_color_occurrences"]:
        warnings.append("发现候选硬编码颜色；SVG、品牌色或平台样式需结合上下文复核")
    if not report["package"]["relevant_check_scripts"]:
        warnings.append("未发现明显的 UI/质量检查 npm script")
    if project_type == "未识别":
        warnings.append("项目入口未识别，不能仅凭本报告判断微信端 UI")
    report["warnings"] = warnings
    return report


def human_report(report: dict[str, Any]) -> str:
    source = report["source_metrics"]
    package = report["package"]
    lines = [
        f"项目：{report['project_root']}",
        f"形态：{report['project_type']}",
        f"页面：{report['page_count']}，组件：{report['component_count']}",
        f"UI 源文件：{source['ui_source_files']}，候选硬编码颜色：{source['candidate_hardcoded_color_occurrences']} 处",
        f"图片资源：{report['image_metrics']['image_files']} 个，{report['image_metrics']['image_bytes']} bytes",
        f"token/theme 候选文件：{report['token_candidate_count']} 个",
        f"可用检查脚本：{', '.join(package['relevant_check_scripts']) or '未发现'}",
    ]
    if report["signals"]:
        lines.append("识别信号：")
        lines.extend(f"  - {signal}" for signal in report["signals"])
    if report["token_candidates"]:
        lines.append("token 候选：")
        lines.extend(f"  - {path}" for path in report["token_candidates"][:12])
    if report["warnings"]:
        lines.append("需要人工复核：")
        lines.extend(f"  - {warning}" for warning in report["warnings"])
    else:
        lines.append("静态基线：未发现需要额外提示的项目级风险；仍需模拟器/真机截图验收。")
    return "\n".join(lines)


def main() -> int:
    args = parse_args()
    root = args.project_root.expanduser().resolve()
    if not root.is_dir():
        print(f"错误：项目目录不存在或不是目录：{root}", file=sys.stderr)
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
