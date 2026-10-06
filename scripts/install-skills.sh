#!/usr/bin/env bash
# install-skills.sh — 把本仓自研的 kit-* skills 同步到安装目录，
# 并打印外部筛选 skills 的安装提示（完整清单见仓库根 SKILLS.md）。
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
TARGETS=("$HOME/.agents/skills" "$HOME/.claude/skills")

for dir in "$REPO"/skills/*/; do
  name="$(basename "$dir")"
  for t in "${TARGETS[@]}"; do
    mkdir -p "$t"
    rm -rf "$t/$name"
    cp -R "$dir" "$t/$name"
    echo "installed: $name -> $t"
  done
done

cat <<'EOF'

外部 skills 不在本仓（清单与来源见 SKILLS.md）。装机时按来源二选一：
  - GitHub 仓：clone 后把对应 skill 子目录拷到 ~/.agents/skills 与 ~/.claude/skills
  - SkillHub / 本地副本：直接整目录拷贝
  - wechatide-skill：从开发者工具 app 包复制（各仓库 AGENTS.md §1）
EOF
