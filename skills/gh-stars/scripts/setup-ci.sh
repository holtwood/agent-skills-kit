#!/usr/bin/env bash
#
# gh-stars — 写入「每周自动同步」GitHub Actions workflow
#
# 用法:
#   setup-ci.sh [目标仓库目录] [--branch main]
#
# 作用:
#   1. 把本 skill 的 scripts/ 复制到 <目标仓库>/skills/gh-stars/（保证 skill 自治、可被 workflow 调用）
#   2. 写入 .github/workflows/sync-stars.yml：每周拉取 Star → 生成索引 → 有变更则自动提交推送
#
set -euo pipefail

TARGET="${1:-$(pwd)}"
BRANCH="main"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --branch)
      [[ $# -ge 2 ]] || { echo "✗ --branch 需要一个分支名参数" >&2; exit 2; }
      BRANCH="$2"; shift 2 ;;
    -h|--help) echo "用法: setup-ci.sh [目标仓库目录] [--branch main]"; exit 0 ;;
    *) shift ;;
  esac
done

[[ -d "${TARGET}/.git" || -d "${TARGET}" ]] || { echo "✗ 目标目录不存在: ${TARGET}" >&2; exit 1; }

SKILL_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${TARGET}/skills/gh-stars"
mkdir -p "${DEST}/scripts"
# 排除 __pycache__，仅复制脚本
tar cf - --exclude='__pycache__' -C "${SKILL_SRC}" scripts | tar xf - -C "${DEST}"
mkdir -p "${TARGET}/.github/workflows" "${TARGET}/data" "${TARGET}/docs"

cat > "${TARGET}/.github/workflows/sync-stars.yml" <<EOF
name: Sync gh-stars
on:
  schedule:
    - cron: "0 2 * * 1"   # 每周一 02:00 UTC
  workflow_dispatch:       # 支持手动触发
permissions:
  contents: write
jobs:
  sync:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: 拉取 Star 列表并生成索引站
        env:
          GH_TOKEN: \${{ secrets.GITHUB_TOKEN }}
          # 仓库在组织名下或要展示他人收藏时，在仓库 Settings → Variables 设置 STARS_OWNER
          OWNER: \${{ vars.STARS_OWNER || github.repository_owner }}
        run: |
          set -euo pipefail
          bash skills/gh-stars/scripts/fetch-stars.sh "\${OWNER}" data/starred_full.json
          python3 skills/gh-stars/scripts/gen-index.py data/starred_full.json docs/index.html --owner "\${OWNER}"
      - name: 有更新则提交推送
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add data docs
          if git diff --cached --quiet; then
            echo "ℹ 无变更，跳过提交"
          else
            git commit -m "chore: 同步 Star 收藏 \$(date -u +%F)"
            git push origin "${BRANCH}"
          fi
EOF

echo "✅ 已写入 ${TARGET}/.github/workflows/sync-stars.yml"
echo "   skill 脚本已复制到 ${DEST}/"
echo "   默认拉取仓库 owner 的 Star；仓库在组织名下或要展示他人收藏时，"
echo "   请在仓库 Settings → Secrets and variables → Actions → Variables 添加 STARS_OWNER"
echo "   （请在仓库 Settings → Actions 确认已允许 GITHUB_TOKEN 写权限，或将默认分支改为 ${BRANCH}）"
