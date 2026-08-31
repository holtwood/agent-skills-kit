#!/usr/bin/env bash
#
# project-hub — 拉取账号下全部仓库列表（参考 page-repos）
#
# 用法:
#   fetch-repos.sh <owner> <out.json> [--include-forks]
#
set -uo pipefail

OWNER="${1:?用法: fetch-repos.sh <owner> <out.json> [--include-forks]}"
OUT="${2:-repos.json}"
INCLUDE_FORKS=0

if [[ "${3:-}" == "--include-forks" ]]; then
  INCLUDE_FORKS=1
fi

mkdir -p "$(dirname "${OUT}")"

if [[ "${OWNER}" == "@me" ]]; then
  OWNER="$(gh api user --jq .login)"
fi

FLAGS=""
[[ "${INCLUDE_FORKS}" -eq 1 ]] && FLAGS="--include-forks"

# shellcheck disable=SC2086
gh repo list "${OWNER}" --limit 1000 ${FLAGS} --json \
  name,description,primaryLanguage,stargazerCount,updatedAt,isFork,isArchived,url,homepageUrl \
  --jq 'map({
    name,
    description,
    language: .primaryLanguage.name,
    stargazersCount: .stargazerCount,
    updatedAt,
    fork: .isFork,
    archived: .isArchived,
    url,
    homepage: .homepageUrl
  })' \
  > "${OUT}"

COUNT="$(python3 -c "import json,sys; print(len(json.load(open('${OUT}'))))")"
echo "✅ 已保存 ${COUNT} 个仓库到 ${OUT}"