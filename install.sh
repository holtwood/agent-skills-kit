#!/usr/bin/env bash
#
# shotkit 一键安装：把 skills 链接到 opencode 与 Claude Code
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPENCODE_DIR="${OPENCODE_SKILLS_DIR:-${HOME}/.config/opencode/skills}"
CLAUDE_DIR="${CLAUDE_SKILLS_DIR:-${HOME}/.claude/skills}"

install_into() {
  local target="$1"
  mkdir -p "${target}"
  for skill in "${REPO_DIR}"/skills/*/; do
    local name
    name="$(basename "${skill}")"
    local link="${target}/${name}"
    if [[ -L "${link}" || -e "${link}" ]]; then
      echo "  · ${link} 已存在，跳过"
    else
      ln -s "${skill%/}" "${link}"
      echo "  · ${link} ← ${skill%/}"
    fi
  done
}

echo "安装 shotkit skills →"
install_into "${OPENCODE_DIR}"
install_into "${CLAUDE_DIR}"
echo "完成。重启 opencode / Claude Code 后即可使用：shotframe、wsl-capture"