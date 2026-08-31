#!/usr/bin/env bash
#
# gh-stars — 拉取 GitHub Star 列表（参考 page-stars/fetch_stars.sh）
#
# 用法:
#   fetch-stars.sh <owner> <out.json>
#
set -euo pipefail

OWNER="${1:?用法: fetch-stars.sh <owner> <out.json>}"
OUT="${2:-starred_full.json}"

mkdir -p "$(dirname "${OUT}")"

# 当前用户简写
if [[ "${OWNER}" == "@me" ]]; then
  OWNER="$(gh api user --jq .login)"
fi

gh api --paginate -H 'Accept: application/vnd.github.star+json' \
  "users/${OWNER}/starred?per_page=100" --jq \
  '.[] | {starred_at: .starred_at} + (.repo | {id, node_id, full_name, description, language, topics, stargazers_count, fork, archived, html_url})' \
  > "${OUT}"

COUNT="$(python3 -c 'import sys; print(sum(1 for _ in sys.stdin))' < "${OUT}")"
echo "✅ 已保存 ${COUNT} 个 Star 到 ${OUT}"