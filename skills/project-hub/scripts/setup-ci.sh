#!/usr/bin/env bash
#
# project-hub — 写入「每周仓库审计」GitHub Actions workflow
#
# 用法:
#   setup-ci.sh [目标仓库目录] [--branch main]
#
# 作用:
#   1. 把本 skill 的 scripts/ 复制到 <目标仓库>/skills/project-hub/（保证 skill 自治、可被 workflow 调用）
#   2. 写入 .github/workflows/audit-weekly.yml：每周拉取仓库列表 → 重新生成导航页 → 有变更则自动提交推送
#      （提交历史即审计留痕：git log 可追溯每周仓库变化）
#
set -euo pipefail

TARGET="${1:-$(pwd)}"
BRANCH="main"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --branch) BRANCH="$2"; shift 2 ;;
    -h|--help) echo "用法: setup-ci.sh [目标仓库目录] [--branch main]"; exit 0 ;;
    *) shift ;;
  esac
done

[[ -d "${TARGET}" ]] || { echo "✗ 目标目录不存在: ${TARGET}" >&2; exit 1; }

SKILL_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${TARGET}/skills/project-hub"
mkdir -p "${DEST}/scripts"
# 排除 __pycache__，仅复制脚本
tar cf - --exclude='__pycache__' -C "${SKILL_SRC}" scripts | tar xf - -C "${DEST}"
mkdir -p "${TARGET}/.github/workflows" "${TARGET}/data" "${TARGET}/docs"

cat > "${TARGET}/.github/workflows/audit-weekly.yml" <<EOF
name: Audit project-hub
on:
  schedule:
    - cron: "0 2 * * 1"   # 每周一 02:00 UTC
  workflow_dispatch:       # 支持手动触发
permissions:
  contents: write
jobs:
  audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: 拉取仓库列表并重新生成导航页
        env:
          GH_TOKEN: \${{ secrets.GITHUB_TOKEN }}
        run: |
          set -euo pipefail
          OWNER="\${GITHUB_REPOSITORY%/*}"
          bash skills/project-hub/scripts/fetch-repos.sh "\${OWNER}" data/repos.json
          python3 skills/project-hub/scripts/gen-hub.py data/repos.json docs/index.html --owner "\${OWNER}"
      - name: 有更新则提交推送（审计留痕）
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add data docs
          if git diff --cached --quiet; then
            echo "ℹ 无变更，跳过提交"
          else
            git commit -m "chore: 每周仓库审计 \$(date -u +%F)"
            git push origin "${BRANCH}"
          fi
EOF

echo "✅ 已写入 ${TARGET}/.github/workflows/audit-weekly.yml"
echo "   skill 脚本已复制到 ${DEST}/"
echo "   （请在仓库 Settings → Actions 确认已允许 GITHUB_TOKEN 写权限，或将默认分支改为 ${BRANCH}）"
