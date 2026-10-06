#!/usr/bin/env python3
"""Create/check local article bundles and export Astro Markdown; never publish."""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

SKILL_ROOT = Path(__file__).resolve().parent.parent
PLATFORMS = ("wechat", "astro", "zhihu", "toutiao")
SCAFFOLD = "<!-- kit:scaffold -->"


def local_path(root: Path, value: str) -> Path:
    if not isinstance(value, str) or not value or Path(value).is_absolute():
        raise ValueError("文件路径必须为工作区内的相对路径")
    path = (root / value).resolve()
    if not path.is_relative_to(root) or path == root:
        raise ValueError(f"路径越出工作区或不是文件: {value}")
    return path


def nonempty(value, label: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"{label} 必须为非空字符串")
    return value


def load_bundle(root: Path) -> dict:
    data = json.loads(local_path(root, "bundle.json").read_text(encoding="utf-8"))
    if not isinstance(data, dict) or type(data.get("version")) is not int or data["version"] != 1:
        raise ValueError("bundle.json 必须使用 version: 1")
    if not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", nonempty(data.get("slug"), "slug")):
        raise ValueError("slug 必须使用小写字母、数字和连字符")
    local_path(root, data.get("master"))
    platforms = data.get("platforms")
    if not isinstance(platforms, dict) or not platforms:
        raise ValueError("platforms 必须为非空对象")
    drafts = {local_path(root, data["master"])}
    for name, item in platforms.items():
        if name == "master" or not re.fullmatch(r"[a-z][a-z0-9-]*", name) or not isinstance(item, dict):
            raise ValueError("平台 ID 或平台对象无效")
        draft = local_path(root, item.get("draft"))
        if draft in drafts:
            raise ValueError("母稿与各平台稿必须使用独立文件")
        drafts.add(draft)
    for key in ("facts", "assets", "must_keep"):
        if not isinstance(data.get(key, []), list):
            raise ValueError(f"{key} 必须为数组")
    return data


def check(root: Path, data: dict, selected: list[str]) -> list[str]:
    errors, texts = [], {}
    for name in selected:
        if name not in data["platforms"]:
            raise ValueError(f"没有平台: {name}")
    files = {"master": data["master"]}
    files.update({name: data["platforms"][name]["draft"] for name in selected})
    for name, relative in files.items():
        try:
            text = local_path(root, relative).read_text(encoding="utf-8")
            texts[name] = text
            if SCAFFOLD in text or not re.sub(r"<!--.*?-->", "", text, flags=re.S).strip():
                errors.append(f"{relative}: 尚未完成正文")
        except (OSError, ValueError) as exc:
            errors.append(f"{relative}: {exc}")
    for name in selected:
        for key in ("title", "summary"):
            try:
                nonempty(data["platforms"][name].get(key), f"{name}.{key}")
            except ValueError as exc:
                errors.append(str(exc))
    ids = set()
    for fact in data.get("facts", []):
        try:
            if not isinstance(fact, dict):
                raise ValueError("fact 必须为对象")
            identifier = nonempty(fact.get("id"), "fact.id")
            if identifier in ids:
                raise ValueError(f"fact.id 重复: {identifier}")
            ids.add(identifier)
            nonempty(fact.get("statement"), f"{identifier}.statement")
            nonempty(fact.get("source"), f"{identifier}.source")
        except ValueError as exc:
            errors.append(str(exc))
    for asset in data.get("assets", []):
        try:
            if not isinstance(asset, dict):
                raise ValueError("asset 必须为对象")
            path = local_path(root, asset.get("path"))
            if not path.is_file() or path.stat().st_size == 0:
                raise ValueError(f"素材缺失或为空: {asset.get('path')}")
            nonempty(asset.get("source"), "asset.source")
        except (OSError, ValueError) as exc:
            errors.append(str(exc))
    for item in data.get("must_keep", []):
        try:
            if not isinstance(item, dict):
                raise ValueError("must_keep 条目必须为对象")
            token = nonempty(item.get("text"), "must_keep.text")
            targets = item.get("targets", ["master", *data["platforms"]])
            if not isinstance(targets, list) or not targets or any(
                not isinstance(name, str) or name not in {"master", *data["platforms"]} for name in targets
            ):
                raise ValueError("must_keep.targets 必须包含已声明的平台 ID 或 master")
            for name in targets:
                if name in texts and token not in texts[name]:
                    errors.append(f"{name}: 缺少需原样保留的内容 {token!r}")
        except ValueError as exc:
            errors.append(str(exc))
    return errors


def initialize(root: Path, slug: str, platforms: list[str]) -> list[str]:
    if not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", slug) or len(slug) > 80:
        raise ValueError("slug 必须为不超过 80 字符的小写字母、数字和连字符")
    platforms = list(dict.fromkeys(platforms))
    data = {"version": 1, "slug": slug, "master": "article.md", "platforms": {},
            "facts": [], "assets": [], "must_keep": []}
    files = {"article.md": SCAFFOLD + "\n", "brief.md":
             (SKILL_ROOT / "assets/article-brief.md").read_text(encoding="utf-8")}
    for name in platforms:
        filename = "article-astro-body.md" if name == "astro" else f"article-{name}.md"
        data["platforms"][name] = {"draft": filename, "title": "", "summary": ""}
        if name == "astro":
            data["platforms"][name]["frontmatter"] = {"title": "", "description": "", "draft": True}
        files[filename] = SCAFFOLD + "\n"
    files["bundle.json"] = json.dumps(data, ensure_ascii=False, indent=2) + "\n"
    # Preflight every destination before creating anything; preserve existing articles.
    for filename in files:
        path = local_path(root, filename)
        if path.exists() or (root / filename).is_symlink():
            raise ValueError(f"保留已有文件，未创建工作区: {filename}")
    image_dir = root / "img"
    if image_dir.is_symlink() or (image_dir.exists() and not image_dir.is_dir()):
        raise ValueError("img 必须是工作区内的普通目录")
    root.mkdir(parents=True, exist_ok=True)
    image_dir.mkdir(exist_ok=True)
    for filename, content in files.items():
        with local_path(root, filename).open("x", encoding="utf-8") as handle:
            handle.write(content)
    return list(files)


def export_astro(root: Path, data: dict, output: str) -> str:
    if "astro" not in data["platforms"]:
        raise ValueError("清单没有 astro 平台")
    errors = check(root, data, ["astro"])
    if errors:
        raise ValueError("; ".join(errors))
    item = data["platforms"]["astro"]
    metadata = item.get("frontmatter")
    if not isinstance(metadata, dict) or not metadata:
        raise ValueError("astro.frontmatter 必须按网站 schema 填写为非空对象")
    metadata = dict(metadata)
    for key, fallback in (("title", item["title"]), ("description", item["summary"])):
        if key in metadata and metadata[key] == "":
            metadata[key] = fallback
    if any(not isinstance(key, str) or not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_-]*", key) for key in metadata):
        raise ValueError("frontmatter 字段名必须为单行标识符")
    if any(value is None or value == "" for value in metadata.values()):
        raise ValueError("frontmatter 仍有空值；请填写或移除非必需字段")
    body = local_path(root, item["draft"]).read_text(encoding="utf-8")
    if body.startswith("---\n") or body.startswith("---\r\n"):
        raise ValueError("Astro body 已有 frontmatter；请保留元数据到清单后再导出")
    path = local_path(root, output)
    reserved = [data["master"], "bundle.json", "brief.md"]
    reserved += [target["draft"] for target in data["platforms"].values()]
    reserved += [asset["path"] for asset in data.get("assets", [])]
    if path in {local_path(root, name) for name in reserved} or path.exists() or (root / output).is_symlink():
        raise ValueError(f"保留已有/源文件，请指定新的输出路径: {output}")
    # Keep relative image/link bases stable. Site-side relocation needs separate validation.
    if path.parent != local_path(root, item["draft"]).parent:
        raise ValueError("Astro 输出必须与 body 同目录，以保持相对资源路径")
    header = "\n".join(f"{key}: {json.dumps(value, ensure_ascii=False, allow_nan=False)}"
                       for key, value in metadata.items())
    with path.open("x", encoding="utf-8") as handle:
        handle.write(f"---\n{header}\n---\n\n{body}")
    return str(path)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    init = sub.add_parser("init", help="创建带待写标记的工作区，不覆盖已有文件")
    init.add_argument("directory", type=Path)
    init.add_argument("--slug", required=True)
    init.add_argument("--platforms", nargs="+", choices=PLATFORMS, default=list(PLATFORMS))
    verify = sub.add_parser("check", help="检查清单、正文、声明素材和保护文字")
    verify.add_argument("directory", type=Path)
    verify.add_argument("--platforms", nargs="+")
    astro = sub.add_parser("astro", help="从清单和 body 生成 Astro Markdown；不写入网站")
    astro.add_argument("directory", type=Path)
    astro.add_argument("--output", default="article-astro.md")
    for command in (init, verify, astro):
        command.add_argument("--json", action="store_true")
    args = parser.parse_args()
    result = {"ok": False, "command": args.command, "publication": "not-attempted"}
    try:
        root = args.directory.resolve()
        if args.command == "init":
            result["files"] = initialize(root, args.slug, args.platforms)
        else:
            data = load_bundle(root)
            if args.command == "check":
                selected = args.platforms or list(data["platforms"])
                result["errors"] = check(root, data, selected)
                result["platforms"] = selected
                result["limitations"] = ["未验证事实语义", "只检查清单声明的素材", "未运行网站构建或编辑器核验"]
                if result["errors"]:
                    raise ValueError("本地材料检查未通过")
            else:
                result["output"] = export_astro(root, data, args.output)
                result["siteValidation"] = "not-run"
        result["ok"] = True
    except (OSError, ValueError, TypeError, KeyError) as exc:
        result["error"] = str(exc)
    result["exitCode"] = 0 if result["ok"] else 1
    if args.json:
        print(json.dumps(result, ensure_ascii=False))
    else:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    return result["exitCode"]


if __name__ == "__main__":
    raise SystemExit(main())
