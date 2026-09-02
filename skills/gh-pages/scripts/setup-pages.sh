#!/usr/bin/env bash
#
# gh-pages — 为仓库配置 GitHub Pages（自动探测构建工具）
#
# 用法:
#   setup-pages.sh <owner/repo> [--mode auto|workflow|branch] [--dir docs] [--branch main] [--output dist]
#
# 探测结果:
#   node       → package.json 有 build 脚本（Vite / Vue / React 等）→ GitHub Actions workflow
#   vitepress  → package.json 依赖含 vitepress                        → GitHub Actions workflow
#   hugo       → 检测到 hugo.toml 等（config.toml 需搭配 Hugo 特征目录）    → GitHub Actions workflow（Hugo 构建）
#   jekyll     → 检测到 _config.yml                                    → 分支部署（Pages 原生构建 Jekyll）
#   branch     → 纯静态（README / index.html / 无构建）               → 分支部署
#
set -euo pipefail

if [[ $# -lt 1 || -z "${1:-}" ]]; then
  echo "用法: setup-pages.sh <owner/repo> [--mode auto|workflow|branch] [--dir docs] [--branch main] [--output dist]" >&2
  exit 2
fi
REPO="$1"
shift

MODE="auto"
DIR="docs"
BRANCH=""
OUTPUT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) MODE="$2"; shift 2 ;;
    --dir) DIR="$2"; shift 2 ;;
    --branch) BRANCH="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    *) echo "未知参数: $1" >&2; exit 2 ;;
  esac
done

# 兼容 --dir /docs 这类带前导斜杠的写法，避免拼出 //docs
DIR="${DIR#/}"

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

has_file() {
  gh api "repos/${REPO}/contents/$1" --jq '.type' >/dev/null 2>&1
}

# 读取仓库根目录的 package.json（取不到返回空）
get_package_json() {
  gh api "repos/${REPO}/contents/package.json" --jq '.content' 2>/dev/null \
    | base64 -d 2>/dev/null || true
}

# 检查 package.json 的 scripts 里是否存在 $1
has_script() {
  local pkg
  pkg="$(get_package_json)"
  [[ -n "${pkg}" ]] || return 1
  echo "${pkg}" | python3 -c 'import json,sys
name = sys.argv[1]
try:
    d = json.load(sys.stdin); s = d.get("scripts") or {}
    sys.exit(0 if s.get(name) else 1)
except Exception:
    sys.exit(1)' "$1" >/dev/null 2>&1
}

# 检查 package.json 依赖里是否含 vitepress
has_vitepress() {
  local pkg
  pkg="$(get_package_json)"
  [[ -n "${pkg}" ]] || return 1
  echo "${pkg}" | python3 -c 'import json,sys
try:
    d = json.load(sys.stdin)
    deps = {**d.get("dependencies", {}), **d.get("devDependencies", {})}
    sys.exit(0 if "vitepress" in deps else 1)
except Exception:
    sys.exit(1)' >/dev/null 2>&1
}

detect_builder() {
  # Hugo 配置是最具体的信号（hugo.toml / hugo.yaml / hugo.json）
  # config.toml 单独出现不视为 Hugo（Rust/Python 等项目也有 config.toml），
  # 需搭配 Hugo 特征目录（archetypes / content / layouts）佐证，避免误判导致部署必坏
  # 注意要放在 package.json 之前：Hugo 站点常带 package.json（postcss/tailwind 资源构建），
  # 先判 package.json 会把这类站点误判为 node 并用 dist/ 产物（实际 Hugo 输出 public/）
  if has_file "hugo.toml" || has_file "hugo.yaml" || has_file "hugo.json" \
     || { has_file "config.toml" && { has_file "archetypes" || has_file "content" || has_file "layouts"; }; }; then
    echo "hugo"; return
  fi
  local pkg
  pkg="$(get_package_json)"
  if [[ -n "${pkg}" ]]; then
    # vitepress 依赖是强信号：官方脚手架默认只有 docs:build（没有 build），必须先于 build 脚本判断
    if has_vitepress; then
      echo "vitepress"; return
    fi
    # package.json 且含 scripts.build → node（Vite / Vue / React 等）
    if has_script "build"; then
      echo "node"; return
    fi
  fi
  # Jekyll（GitHub Pages 原生构建）
  if has_file "_config.yml" || has_file "_config.yaml"; then
    echo "jekyll"; return
  fi
  echo "branch"
}

WORKFLOW_FRAMEWORKS="node vitepress hugo"

# 始终探测一次框架：auto 用它决定部署方式，强制 workflow 模式也用它取默认产物目录
DETECTED="$(detect_builder)"

MODE_NAME="${MODE}"
if [[ "${MODE}" == "auto" ]]; then
  MODE_NAME="${DETECTED}"
  echo "🔍 探测结果: ${MODE_NAME} → $([[ " ${WORKFLOW_FRAMEWORKS} " == *" ${MODE_NAME} "* ]] && echo 'Actions workflow 部署' || echo '分支部署')"
fi

# workflow 模式的产物目录（无论 auto 还是强制 workflow，都按探测到的框架取默认，可用 --output 覆盖）
case "${DETECTED}" in
  vitepress) OUTPUT_DEFAULT="docs/.vitepress/dist" ;;
  hugo)      OUTPUT_DEFAULT="public" ;;
  node)      OUTPUT_DEFAULT="dist" ;;
  *)         OUTPUT_DEFAULT="" ;;
esac
OUTPUT="${OUTPUT:-${OUTPUT_DEFAULT}}"

# node/vitepress 的构建命令：vitepress 官方脚手架默认只有 docs:build（没有 build）
# 仅对可构建框架赋值；静态站/jekyll 强制 workflow 时保持为空，走下方报错分支，避免生成必失败的 workflow
BUILD_CMD=""
case "${DETECTED}" in
  node)
    BUILD_CMD="npm run build"
    ;;
  vitepress)
    if has_script "build"; then
      BUILD_CMD="npm run build"
    elif has_script "docs:build"; then
      BUILD_CMD="npm run docs:build"
    fi
    ;;
esac

WORKFLOW_PATH=".github/workflows/gh-pages.yml"
WORKFLOW_SHA="$(gh api "repos/${REPO}/contents/${WORKFLOW_PATH}" --jq '.sha' 2>/dev/null || echo "")"

write_workflow() {
  # $1 = 产物目录
  local outdir="$1"
  local build_steps=""
  # 构建步骤按「探测到的框架」决定（auto 与强制 workflow 均适用）
  case "${DETECTED}" in
    hugo)
      build_steps='      - uses: peaceiris/actions-hugo@v3
        with:
          hugo-version: "latest"
      - run: hugo --minify'
      ;;
    *) # node / vitepress
      build_steps="      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm
      - run: npm ci || npm install
      - run: ${BUILD_CMD}"
      ;;
  esac
  cat > "${TMP_WF}" <<EOF
name: Deploy to GitHub Pages
on:
  push:
    branches: [${DEFAULT_BRANCH}]
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
        with:
          submodules: recursive
${build_steps}
      - uses: actions/configure-pages@v5
      - uses: actions/upload-pages-artifact@v3
        with:
          path: ${outdir}
  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: \${{ steps.deployment.outputs.page_url }}
    steps:
      - id: deployment
        uses: actions/deploy-pages@v4
EOF
}

if [[ "${MODE}" == "workflow" ]] || [[ " ${WORKFLOW_FRAMEWORKS} " == *" ${MODE_NAME} "* ]]; then
  # ---- Workflow 部署（node / vitepress / hugo，或强制 --mode workflow） ----
  if [[ -z "${OUTPUT}" ]]; then
    echo "✗ workflow 部署需要可构建的仓库（当前探测: ${DETECTED}），无法确定产物目录" >&2
    echo "  若确需 workflow，请用 --output <目录> 指定构建产物，或确认仓库有构建脚本" >&2
    exit 2
  fi
  if [[ "${DETECTED}" != "hugo" && -z "${BUILD_CMD}" ]]; then
    echo "✗ 仓库没有可用的构建脚本（探测: ${DETECTED}），无法生成构建步骤" >&2
    echo "  请确认仓库可构建，或改用分支部署（--mode branch / --dir docs）" >&2
    exit 2
  fi
  if [[ -z "${WORKFLOW_SHA}" ]]; then
    TMP_WF="$(mktemp)"
    trap 'rm -f "${TMP_WF}"' EXIT
    write_workflow "${OUTPUT}"
    CONTENT="$(base64 < "${TMP_WF}" | tr -d '\n')"
    gh api "repos/${REPO}/contents/${WORKFLOW_PATH}" \
      -X PUT -f message="chore: enable GitHub Pages via Actions (${DETECTED})" \
      -f content="${CONTENT}" >/dev/null && echo "✅ workflow 已写入: ${WORKFLOW_PATH}（构建产物: ${OUTPUT}）"
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
  # ---- 分支部署（jekyll / branch / 纯静态） ----
  # Jekyll 由 Pages 原生构建，源目录应为仓库根；其他静态站默认 /docs
  SOURCE_PATH="/${DIR}"
  if [[ "${DETECTED}" == "jekyll" ]]; then
    SOURCE_PATH="/"
    echo "ℹ 检测到 Jekyll：Pages 会原生构建，源目录指向仓库根"
  fi
  # GitHub legacy source 只支持 / 与 /docs，提前提示避免 API 422
  if [[ "${SOURCE_PATH}" != "/" && "${SOURCE_PATH}" != "/docs" ]]; then
    echo "⚠ GitHub Pages 分支部署的源目录只支持 / 或 /docs（收到: ${SOURCE_PATH}），API 可能拒绝"
  fi
  if [[ "${SOURCE_PATH}" != "/" ]] && ! gh api "repos/${REPO}/contents/${DIR}" --jq '.type' >/dev/null 2>&1; then
    echo "⚠ 仓库中没有 ${DIR}/ 目录，Pages 会显示 404，请先放一个 index.html 进去"
  fi
  if [[ "${HAS_PAGES}" == "true" ]]; then
    if ! gh api "repos/${REPO}/pages" -X PUT \
      -f build_type=legacy \
      -f "source[branch]=${BRANCH}" -f "source[path]=${SOURCE_PATH}" >/dev/null 2>&1; then
      echo "✗ 更新 Pages 源失败（检查 token 权限）" >&2
      exit 1
    fi
  else
    if ! gh api "repos/${REPO}/pages" -X POST \
      -f build_type=legacy \
      -f "source[branch]=${BRANCH}" -f "source[path]=${SOURCE_PATH}" >/dev/null 2>&1; then
      echo "✗ 创建 Pages 失败（检查 token 权限）" >&2
      exit 1
    fi
  fi
  echo "✅ Pages 源已设为 ${BRANCH} 分支 ${SOURCE_PATH} 目录"
fi

OWNER="$(echo "${REPO}" | cut -d/ -f1)"
echo "🌐 发布地址: https://${OWNER}.github.io/$(echo "${REPO}" | cut -d/ -f2)/"
echo "⏳ 首次部署需等待 1-3 分钟，可运行 gh api repos/${REPO}/pages --jq .status 查询"
