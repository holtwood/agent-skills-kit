#!/usr/bin/env python3
"""Validate this repository's two-scalar skill frontmatter and local resources.

Uses only the standard library. This is a repository check, not a general YAML parser.
"""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parent.parent
LINK = re.compile(r"\[[^\]]*\]\((?:<([^>]+)>|([^\s)]+))(?:\s+[^)]*)?\)")


def metadata(text: str) -> tuple[dict[str, str], str]:
    match = re.match(r"\A---\n(.*?)\n---(?:\n|$)", text, re.S)
    if not match:
        raise ValueError("缺少有效 YAML frontmatter")
    result = {}
    for line in match[1].splitlines():
        key, separator, value = line.partition(":")
        if not separator or key not in {"name", "description"} or key in result:
            raise ValueError("仓库 frontmatter 只允许唯一的 name 与 description 字符串")
        value = value.strip()
        if value.startswith('"'):
            value = json.loads(value)
        elif value.startswith("'") and value.endswith("'"):
            value = value[1:-1].replace("''", "'")
        elif ": " in value or value.startswith(("[", "{", "|", ">", "&", "*", "!", "#")):
            raise ValueError("复杂 YAML 字符串请使用双引号")
        if not isinstance(value, str) or not value.strip():
            raise ValueError(f"{key} 必须是非空字符串")
        result[key] = value
    if set(result) != {"name", "description"}:
        raise ValueError("name 与 description 均为必填项")
    return result, text[match.end():]


def local_links(path: Path):
    for match in LINK.finditer(path.read_text(encoding="utf-8")):
        target = match[1] or match[2]
        uri = urlsplit(target)
        if uri.scheme or uri.netloc or not uri.path:
            continue
        yield (path.parent / unquote(uri.path)).resolve()


def validate(skill: Path) -> list[str]:
    errors = []
    entry = skill / "SKILL.md"
    try:
        text = entry.read_text(encoding="utf-8")
        front, body = metadata(text)
    except (OSError, ValueError) as exc:
        return [f"{entry}: {exc}"]
    name = front["name"]
    if not re.fullmatch(r"kit-[a-z0-9]+(?:-[a-z0-9]+)*", name) or len(name) > 64 or name != skill.name:
        errors.append(f"{entry}: name 必须与目录一致，使用 kit- 前缀且长度不超过 64")
    if len(front["description"]) > 1024 or any(c in front["description"] for c in "<>"):
        errors.append(f"{entry}: description 过长或含尖括号")
    if re.search(r"\[TODO:", body):
        errors.append(f"{entry}: 残留脚手架占位符")
    pending, seen = [entry.resolve()], set()
    while pending:
        doc = pending.pop()
        if doc in seen:
            continue
        seen.add(doc)
        for linked in local_links(doc):
            if not linked.is_relative_to(skill.resolve()):
                errors.append(f"{doc}: 资源链接越出 skill 目录: {linked}")
            elif not linked.exists():
                errors.append(f"{doc}: 资源不存在: {linked}")
            elif linked.suffix == ".md" and linked.is_file():
                pending.append(linked)
    for reference in (skill / "references").glob("*.md"):
        if reference.resolve() not in seen:
            errors.append(f"{reference}: 没有从入口可达的链接")
    for script in re.findall(r"<SKILL_ROOT>/(scripts/[\w./-]+)", text):
        if not (skill / script).is_file():
            errors.append(f"{entry}: 命令引用了不存在的脚本: {script}")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--skill", type=Path, help="只检查指定 skill；默认检查整套")
    args = parser.parse_args()
    skills = [args.skill.resolve()] if args.skill else sorted((ROOT / "skills").iterdir())
    errors = [error for skill in skills if skill.is_dir() for error in validate(skill)]
    if not args.skill:
        for readme in (ROOT / "README.md", ROOT / "README.en.md"):
            links = set(local_links(readme))
            for skill in skills:
                if skill.resolve() not in links:
                    errors.append(f"{readme}: 索引遗漏 {skill.name}")
    for error in errors:
        print(f"✗ {error}")
    if not errors:
        print(f"✅ {len(skills)} 个 skills：元数据、命令路径、引用可达性与索引通过")
    return int(bool(errors))


if __name__ == "__main__":
    raise SystemExit(main())
