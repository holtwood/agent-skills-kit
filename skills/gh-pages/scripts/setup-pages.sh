#!/usr/bin/env bash
#
# gh-pages — 为仓库配置 GitHub Pages（自动探测构建工具）
#
# 用法:
#   setup-pages.sh <owner/repo> [--mode auto|workflow|branch] [--dir docs] [--branch main]
#
set -euo pipefail

if [[ $# -lt 1 || -z "${1:-}" ]]; then
  echo "用法: setup-pages.sh <owner/repo> [--mode auto|workflow|branch] [--dir docs] [--branch main]" >&2
  exit 2
fi
REPO="$1"
shift

MODE="auto"
DIR="docs"
BRANCH=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) MODE="$2"; shift 2 ;;
    --dir) DIR="$2"; shift 2 ;;
    --branch) BRANCH="$2"; shift 2 ;;
    *) echo "未知参数: $1" >&2; exit 2 ;;
  esac
done

case "${MODE}" in
  auto|workflow|branch) ;;
  *) echo "✗ --mode 必须是 auto|workflow|branch，收到: ${MODE}" >&2; exit 2 ;;
esac

command -v gh >/dev/null 2>&1 || { echo "✗ 需要 gh CLI，请先安装: https://cli.github.com/" >&2; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "✗ gh 未登录，请先 gh auth login" >&2; exit 1; }

# 仓库基本信息（gh api 直接取，避免 gh repo view --json 字段兼容问题）
REPO_JSON="$(gh api "repos/${REPO}" --jq '{default_branch, fork: .fork}')" || exit 1
DEFAULT_BRANCH="$(echo "${REPO_JSON}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["default_branch"])')" || exit 1
BRANCH="${BRANCH:-${DEFAULT_BRANCH}}"

# 判断 Pages 是否已开启（GET /pages 返回 200 即已开，404 即未开）
if gh api "repos/${REPO}/pages" --jq '.status' >/dev/null 2>&1; then
  HAS_PAGES="true"
else
  HAS_PAGES="false"
fi

echo "📦 ${REPO} | 默认分支: ${DEFAULT_BRANCH} | Pages 已开: ${HAS_PAGES}"

detect_builder() {
  # 只有 package.json 且含 scripts.build 才需要 Actions 构建；Hugo/VitePress 等无构建脚本走分支部署
  if gh api "repos/${REPO}/contents/package.json" --jq '.content' 2>/dev/null \
    | base64 -d 2>/dev/null \
    | python3 -c 'import json,sys; sys.exit(0 if (json.load(sys.stdin).get("scripts") or {}).get("build") else 1)' >/dev/null 2>&1; then
    echo "workflow"
  else
    echo "branch"
  fi
}

MODE_NAME="${MODE}"
if [[ "${MODE}" == "auto" ]]; then
  MODE_NAME="$(detect_builder)"
  echo "🔍 探测结果: 使用 ${MODE_NAME} 部署方式"
fi

WORKFLOW_PATH=".github/workflows/gh-pages.yml"
WORKFLOW_SHA="$(gh api "repos/${REPO}/contents/${WORKFLOW_PATH}" --jq '.sha' 2>/dev/null || echo "")"

if [[ "${MODE_NAME}" == "workflow" ]]; then
  # 写一个标准 Pages workflow（如果不存在）
  if [[ -z "${WORKFLOW_SHA}" ]]; then
    TMP_WF="$(mktemp)"
    trap 'rm -f "${TMP_WF}"' EXIT
    cat > "${TMP_WF}" <<'EOF'
name: Deploy to GitHub Pages
on:
  push:
    branches: [main, master]
  workflow_dispatch:
permissions:
  contents: read
  pages: write
  id-token: write
concurrency:
  group: pages
  cancel-in-progress: true
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm
      - run: npm ci
      - run: npm run build
      - uses: actions/configure-pages@v5
      - uses: actions/upload-pages-artifact@v3
        with:
          path: dist
  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - id: deployment
        uses: actions/deploy-pages@v4
EOF
    CONTENT="$(base64 < "${TMP_WF}" | tr -d '\n')"
    gh api "repos/${REPO}/contents/${WORKFLOW_PATH}" \
      -X PUT -f message="chore: enable GitHub Pages via Actions" \
      -f content="${CONTENT}" >/dev/null && echo "✅ workflow 已写入: ${WORKFLOW_PATH}"
  else
    echo "ℹ ${WORKFLOW_PATH} 已存在，跳过写入"
  fi
  # Pages 源指向 GitHub Actions（PUT 更新 / POST 新建，均失败则报错退出，不谎报成功）
  if ! gh api "repos/${REPO}/pages" -X PUT -f build_type=workflow >/dev/null 2>&1; then
    if ! gh api "repos/${REPO}/pages" -X POST -f build_type=workflow >/dev/null 2>&1; then
      echo "✗ 无法设置 Pages 源为 GitHub Actions（检查 token 权限：需要 repo 写权限）" >&2
      exit 1
    fi
  fi
  echo "✅ Pages 源已设为 GitHub Actions"
else
  # 分支部署：确认 DIR 存在（或提示创建），然后设置 source
  if ! gh api "repos/${REPO}/contents/${DIR}" --jq '.type' >/dev/null 2>&1; then
    echo "⚠ 仓库中没有 ${DIR}/ 目录，Pages 会显示 404，请先放一个 index.html 进去"
  fi
  if [[ "${HAS_PAGES}" == "true" ]]; then
    if ! gh api "repos/${REPO}/pages" -X PUT \
      -f build_type=legacy \
      -f "source[branch]=${BRANCH}" -f "source[path]=/${DIR}" >/dev/null 2>&1; then
      echo "✗ 更新 Pages 源失败（检查 token 权限）" >&2
      exit 1
    fi
  else
    if ! gh api "repos/${REPO}/pages" -X POST \
      -f build_type=legacy \
      -f "source[branch]=${BRANCH}" -f "source[path]=/${DIR}" >/dev/null 2>&1; then
      echo "✗ 创建 Pages 失败（检查 token 权限）" >&2
      exit 1
    fi
  fi
  echo "✅ Pages 源已设为 ${BRANCH} 分支 /${DIR} 目录"
fi

OWNER="$(echo "${REPO}" | cut -d/ -f1)"
echo "🌐 发布地址: https://${OWNER}.github.io/$(echo "${REPO}" | cut -d/ -f2)/"
echo "⏳ 首次部署需等待 1-3 分钟，可运行 gh api repos/${REPO}/pages --jq .status 查询"