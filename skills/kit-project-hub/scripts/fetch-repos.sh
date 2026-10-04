#!/usr/bin/env bash
# Fetch real GitHub data atomically: failed requests preserve the previous snapshot.
set -euo pipefail
usage() { echo '用法: fetch-repos.sh <owner|@me> <out.json> [--include-forks]'; }
case "${1:-}" in -h|--help) usage; exit 0 ;; esac
[[ $# -ge 2 && $# -le 3 ]] || { usage >&2; exit 2; }
OWNER="$1"
OUT="$2"
INCLUDE_FORKS=0
if [[ $# -eq 3 ]]; then
  [[ "$3" == --include-forks ]] || { echo "✗ 未知参数: $3" >&2; exit 2; }
  INCLUDE_FORKS=1
fi
[[ -n "$OUT" ]] || { echo '✗ 输出路径不能为空' >&2; exit 2; }
[[ "$OWNER" == @me || "$OWNER" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]*$ ]] || { echo '✗ 账号参数不合法' >&2; exit 2; }
command -v gh >/dev/null || { echo '✗ 需要 gh CLI' >&2; exit 1; }
command -v python3 >/dev/null || { echo '✗ 需要 Python 3' >&2; exit 1; }
if [[ "$OWNER" == @me ]]; then OWNER="$(gh api user --jq .login)"; fi
mkdir -p "$(dirname "$OUT")"
SNAPSHOT="$(mktemp "${OUT}.tmp.XXXXXX")"
trap 'rm -f "$SNAPSHOT"' EXIT
ACCOUNT_TYPE="$(gh api "users/${OWNER}" --jq .type)"
if [[ "$ACCOUNT_TYPE" == Organization ]]; then ENDPOINT="orgs/${OWNER}/repos?type=public&per_page=100"
else ENDPOINT="users/${OWNER}/repos?type=owner&per_page=100"; fi
# Public data only, even when the authenticated token can read private repositories.
gh api --paginate --slurp "$ENDPOINT" --jq 'add | map(select(.private == false))' > "$SNAPSHOT"
python3 - "$SNAPSHOT" "$INCLUDE_FORKS" <<'JSON'
import json, pathlib, sys
p = pathlib.Path(sys.argv[1])
rows = json.loads(p.read_text(encoding='utf-8')) or []
rows = [{"name": r["name"], "description": r.get("description"), "language": r.get("language"),
         "stargazersCount": r.get("stargazers_count", 0), "updatedAt": r.get("updated_at"),
         "fork": bool(r.get("fork")), "archived": bool(r.get("archived")),
         "url": r.get("html_url"), "homepage": r.get("homepage")}
        for r in rows if not r.get("private") and (sys.argv[2] == '1' or not r.get("fork"))]
p.write_text(json.dumps(rows, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
JSON
COUNT="$(python3 -c 'import json,sys; print(len(json.load(sys.stdin)))' < "$SNAPSHOT")"
mv "$SNAPSHOT" "$OUT"
echo "✅ 已保存 ${COUNT} 个 公开仓库 到 ${OUT}"
