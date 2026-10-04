#!/usr/bin/env bash
# Link repository skills without overwriting ordinary files. Compatible with Bash 3.2+.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT="all"
DRY_RUN=0
requested=()
usage() {
  cat <<'EOF'
用法: ./install.sh [--agent all|codex|claude|opencode] [--dry-run] [skill ...]
      ./install.sh --list
无 skill 参数时安装全部。默认链接到三个客户端；已有普通目录不会被覆盖。
目标目录可通过 CODEX_SKILLS_DIR、CLAUDE_SKILLS_DIR、OPENCODE_SKILLS_DIR 覆盖。
EOF
}
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --list) for path in "${REPO_DIR}"/skills/*/SKILL.md; do basename "$(dirname "$path")"; done; exit 0 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --agent)
      [[ $# -ge 2 ]] || { echo '✗ --agent 缺少参数' >&2; exit 2; }
      AGENT="$2"; shift 2 ;;
    -*) echo "✗ 未知参数: $1" >&2; exit 2 ;;
    *) requested+=("$1"); shift ;;
  esac
done
case "$AGENT" in all|codex|claude|opencode) ;; *) echo "✗ 未知客户端: $AGENT" >&2; exit 2 ;; esac
if [[ ${#requested[@]} -eq 0 ]]; then
  for path in "${REPO_DIR}"/skills/*/SKILL.md; do requested+=("$(basename "$(dirname "$path")")"); done
fi
# Validate the whole request before creating any links.
for name in "${requested[@]}"; do
  [[ "$name" != */* && -f "${REPO_DIR}/skills/${name}/SKILL.md" ]] || {
    echo "✗ 找不到 skill: ${name}（使用 --list 查看）" >&2; exit 2;
  }
done
targets=()
if [[ "$AGENT" == all || "$AGENT" == codex ]]; then targets+=("${CODEX_SKILLS_DIR:-${CODEX_HOME:-${HOME}/.codex}/skills}"); fi
if [[ "$AGENT" == all || "$AGENT" == claude ]]; then targets+=("${CLAUDE_SKILLS_DIR:-${HOME}/.claude/skills}"); fi
if [[ "$AGENT" == all || "$AGENT" == opencode ]]; then targets+=("${OPENCODE_SKILLS_DIR:-${HOME}/.config/opencode/skills}"); fi
conflicts=0
for name in "${requested[@]}"; do
  src="${REPO_DIR}/skills/${name}"
  for target in "${targets[@]}"; do
    link="${target}/${name}"
    if [[ -L "$link" && "$(readlink "$link")" == "$src" && -e "$link" ]]; then
      echo "· 已安装: $link"
    elif [[ -e "$link" && ! -L "$link" ]]; then
      echo "✗ 保留已有非链接路径: $link" >&2
      conflicts=1
    elif [[ "$DRY_RUN" -eq 1 ]]; then
      echo "· 计划链接: $link ← $src"
    else
      mkdir -p "$target"
      # Remove only the symlink itself, never its target.
      if [[ -L "$link" ]]; then unlink "$link"; fi
      ln -s "$src" "$link"
      echo "· 已链接: $link ← $src"
    fi
  done
done
[[ "$conflicts" -eq 0 ]] || exit 1
echo '完成。'
