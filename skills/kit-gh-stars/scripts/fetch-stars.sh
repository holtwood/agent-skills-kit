#!/usr/bin/env bash
# Fetch real GitHub data atomically: failed requests preserve the previous snapshot.
set -euo pipefail
usage() { echo '用法: fetch-stars.sh <owner|@me> <out.json>'; }
case "${1:-}" in -h|--help) usage; exit 0 ;; esac
[[ $# -ge 2 && $# -le 2 ]] || { usage >&2; exit 2; }
OWNER="$1"
OUT="$2"
[[ -n "$OUT" ]] || { echo '✗ 输出路径不能为空' >&2; exit 2; }
[[ "$OWNER" == @me || "$OWNER" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]*$ ]] || { echo '✗ 账号参数不合法' >&2; exit 2; }
command -v gh >/dev/null || { echo '✗ 需要 gh CLI' >&2; exit 1; }
command -v python3 >/dev/null || { echo '✗ 需要 Python 3' >&2; exit 1; }
if [[ "$OWNER" == @me ]]; then OWNER="$(gh api user --jq .login)"; fi
mkdir -p "$(dirname "$OUT")"
SNAPSHOT="$(mktemp "${OUT}.tmp.XXXXXX")"
trap 'rm -f "$SNAPSHOT"' EXIT
gh api --paginate -H 'Accept: application/vnd.github.star+json' \
  "users/${OWNER}/starred?per_page=100" --jq \
  '.[] | {starred_at: .starred_at} + (.repo | {id, node_id, full_name, description, language, topics, stargazers_count, fork, archived, html_url})' > "$SNAPSHOT"
COUNT="$(python3 -c 'import json,sys; rows=[json.loads(line) for line in sys.stdin if line.strip()]; print(len(rows))' < "$SNAPSHOT")"
mv "$SNAPSHOT" "$OUT"
echo "✅ 已保存 ${COUNT} 个 Star 到 ${OUT}"
