#!/usr/bin/env bash
# Link repository skills without overwriting ordinary files. Compatible with Bash 3.2+.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT="all"
DRY_RUN=0
BACKUP=0
requested=()
usage() {
  cat <<'EOF'
用法: ./install.sh [--agent all|codex|claude|opencode|zcode|devin|agents|cmdc|deepseek] [--dry-run] [--backup] [skill ...]
      ./install.sh --list
无 skill 参数时安装全部。默认链接到支持的客户端（已有对应主目录或环境配置的客户端均会自动覆盖）；已有普通目录不会被覆盖，除非使用 --backup。
目标目录可通过各客户端的 _SKILLS_DIR 环境变量覆盖。
EOF
}
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --list) for path in "${REPO_DIR}"/skills/*/SKILL.md; do basename "$(dirname "$path")"; done; exit 0 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --backup) BACKUP=1; shift ;;
    --agent)
      [[ $# -ge 2 ]] || { echo '✗ --agent 缺少参数' >&2; exit 2; }
      AGENT="$2"; shift 2 ;;
    -*) echo "✗ 未知参数: $1" >&2; exit 2 ;;
    *) requested+=("$1"); shift ;;
  esac
done
case "$AGENT" in all|everything|codex|claude|opencode|zcode|devin|agents|cmdc|deepseek) ;; *) echo "✗ 未知客户端: $AGENT" >&2; exit 2 ;; esac
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
# Standard clients
if [[ "$AGENT" == all || "$AGENT" == everything || "$AGENT" == codex ]]; then targets+=("${CODEX_SKILLS_DIR:-${CODEX_HOME:-${HOME}/.codex}/skills}"); fi
if [[ "$AGENT" == all || "$AGENT" == everything || "$AGENT" == claude ]]; then targets+=("${CLAUDE_SKILLS_DIR:-${HOME}/.claude/skills}"); fi
if [[ "$AGENT" == all || "$AGENT" == everything || "$AGENT" == opencode ]]; then targets+=("${OPENCODE_SKILLS_DIR:-${HOME}/.config/opencode/skills}"); fi

# Extended agents (zcode, devin, agents harness, cmdc, deepseek)
if [[ "$AGENT" == everything || "$AGENT" == zcode ]]; then targets+=("${ZCODE_SKILLS_DIR:-${HOME}/.zcode/skills}"); fi
if [[ "$AGENT" == everything || "$AGENT" == devin ]]; then targets+=("${DEVIN_SKILLS_DIR:-${HOME}/.devin/skills}"); fi
if [[ "$AGENT" == everything || "$AGENT" == agents ]]; then targets+=("${AGENTS_SKILLS_DIR:-${HOME}/.agents/skills}"); fi
if [[ "$AGENT" == everything || "$AGENT" == cmdc ]]; then targets+=("${CMDC_SKILLS_DIR:-${HOME}/.cmdc/skills}"); fi
if [[ "$AGENT" == everything || "$AGENT" == deepseek ]]; then targets+=("${DEEPSEEK_SKILLS_DIR:-${HOME}/.deepseek/skills}"); fi
conflicts=0
for name in "${requested[@]}"; do
  src="${REPO_DIR}/skills/${name}"
  for target in "${targets[@]}"; do
    link="${target}/${name}"
    if [[ -L "$link" && "$(readlink "$link")" == "$src" && -e "$link" ]]; then
      echo "· 已安装: $link"
    elif [[ -e "$link" && ! -L "$link" ]]; then
      if [[ "$BACKUP" -eq 1 ]]; then
        bak="${link}.backup.$(date +%Y%m%d%H%M%S)"
        if [[ "$DRY_RUN" -eq 1 ]]; then
          echo "· 计划备份原目录: $link → $bak"
          echo "· 计划链接: $link ← $src"
        else
          mkdir -p "$target"
          mv "$link" "$bak"
          echo "· 已备份原目录: $link → $bak"
          ln -s "$src" "$link"
          echo "· 已链接: $link ← $src"
        fi
      else
        echo "✗ 保留已有非链接路径: $link" >&2
        conflicts=1
      fi
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
