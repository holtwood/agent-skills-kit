#!/usr/bin/env bash
# Generate a local scheduled workflow; preserve existing workflows unless --force.
set -euo pipefail
TARGET=""
BRANCH=""
FORCE=0
usage() { echo '用法: setup-ci.sh [项目目录] [--branch NAME] [--force]'; }
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --force) FORCE=1; shift ;;
    --branch)
      [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || { echo '✗ --branch 缺少分支名' >&2; exit 2; }
      BRANCH="$2"; shift 2 ;;
    -*) echo "✗ 未知参数: $1" >&2; exit 2 ;;
    *) [[ -z "$TARGET" ]] || { usage >&2; exit 2; }; TARGET="$1"; shift ;;
  esac
done
TARGET="${TARGET:-$(pwd)}"
[[ -d "$TARGET" ]] || { echo "✗ 目标目录不存在: $TARGET" >&2; exit 2; }
command -v git >/dev/null || { echo '✗ 需要 git' >&2; exit 1; }
command -v python3 >/dev/null || { echo '✗ 需要 Python 3' >&2; exit 1; }
if [[ -z "$BRANCH" ]]; then
  BRANCH="$(git -C "$TARGET" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || true)"
  BRANCH="${BRANCH#origin/}"
fi
if [[ -z "$BRANCH" ]]; then BRANCH="$(git -C "$TARGET" symbolic-ref --short HEAD 2>/dev/null || true)"; fi
BRANCH="${BRANCH:-main}"
git check-ref-format --branch "$BRANCH" >/dev/null || { echo '✗ 分支名不合法' >&2; exit 2; }
WORKFLOW="$TARGET/.github/workflows/sync-stars.yml"
if [[ -e "$WORKFLOW" && "$FORCE" -eq 0 ]]; then
  echo "· 保留已有 workflow: ${WORKFLOW}（明确需要覆盖时使用 --force）"
  exit 0
fi
BRANCH_YAML="$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$BRANCH")"
SKILL_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$TARGET/skills/kit-gh-stars/scripts"
mkdir -p "$DEST" "$TARGET/.github/workflows" "$TARGET/data" "$TARGET/docs"
if [[ "$(cd "$DEST" && pwd)" != "$SKILL_SRC/scripts" ]]; then
  cp "$SKILL_SRC"/scripts/*.sh "$SKILL_SRC"/scripts/*.py "$DEST/"
fi
cat > "$WORKFLOW" <<EOF
name: Update kit-gh-stars
on:
  schedule:
    - cron: "0 2 * * 1"
  workflow_dispatch:
permissions:
  contents: write
concurrency:
  group: sync-\${{ github.ref }}
  cancel-in-progress: false
jobs:
  sync:
    runs-on: ubuntu-latest
    env:
      TARGET_BRANCH: ${BRANCH_YAML}
    steps:
      - uses: actions/checkout@v4
        with:
          ref: ${BRANCH_YAML}
      - name: 更新数据与页面
        env:
          GH_TOKEN: \${{ secrets.GITHUB_TOKEN }}
          OWNER: \${{ vars.STARS_OWNER || github.repository_owner }}
        run: |
          set -euo pipefail
          bash skills/kit-gh-stars/scripts/fetch-stars.sh "\${OWNER}" data/starred_full.json
          args=()
          if [[ -f data/desc_zh.json ]]; then args+=(--desc-zh data/desc_zh.json); fi
          python3 skills/kit-gh-stars/scripts/gen-index.py data/starred_full.json docs/index.html --owner "\${OWNER}" "\${args[@]}"
      - name: 有更新则提交推送
        run: |
          set -euo pipefail
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add data docs
          if ! git diff --cached --quiet; then
            git commit -m "chore: update kit-gh-stars"
            git push origin "HEAD:\${TARGET_BRANCH}"
          fi
EOF
echo "✅ 已写入 ${WORKFLOW}（账号变量 STARS_OWNER，分支 ${BRANCH}）"
