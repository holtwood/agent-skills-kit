#!/usr/bin/env bash
#
# my-agent-skills 一键安装：把指定 skill 链接到 opencode 与 Claude Code
#
# 用法:
#   ./install.sh                 # 安装全部 skill
#   ./install.sh shotframe       # 只安装指定 skill
#   ./install.sh shotframe gh-stars
#
set -euo pipefail

# install.sh 使用了 mapfile -d ''，需要 bash >= 4.4
if (( BASH_VERSINFO[0] < 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 4) )); then
  echo "✗ install.sh 需要 bash ≥ 4.4（当前 $(bash --version | head -1)）" >&2
  echo "  macOS 请用 Homebrew 安装: brew install bash，并以 /usr/local/bin/bash 运行" >&2
  exit 1
fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPENCODE_DIR="${OPENCODE_SKILLS_DIR:-${HOME}/.config/opencode/skills}"
CLAUDE_DIR="${CLAUDE_SKILLS_DIR:-${HOME}/.claude/skills}"

requested=("$@")
if [[ ${#requested[@]} -eq 0 ]]; then
  mapfile -d '' requested < <(find "${REPO_DIR}/skills" -mindepth 1 -maxdepth 1 -type d -print0)
fi

link_one() {
  local target="$1" name="$2" src="$3"
  mkdir -p "${target}"
  local link="${target}/${name}"
  if [[ -L "${link}" ]]; then
    local current
    current="$(readlink "${link}" 2>/dev/null || true)"
    if [[ "${current}" == "${src}" && -e "${link}" ]]; then
      echo "  · ${link} 已指向本仓库且有效，跳过"
    else
      echo "  · ${link} 是旧/失效链接（→ ${current}），重新链接到 ${src}"
      rm -f "${link}"
      ln -s "${src}" "${link}"
    fi
  elif [[ -e "${link}" ]]; then
    echo "  · ${link} 已存在（非链接），跳过"
  else
    ln -s "${src}" "${link}"
    echo "  · ${link} ← ${src}"
  fi
}

for name in "${requested[@]}"; do
  name="$(basename "${name}")"
  local_src="${REPO_DIR}/skills/${name}"
  [[ -d "${local_src}" ]] || { echo "✗ 找不到 skill: ${name}" >&2; exit 1; }
  echo "安装 ${name} →"
  link_one "${OPENCODE_DIR}" "${name}" "${local_src}"
  link_one "${CLAUDE_DIR}" "${name}" "${local_src}"
done

echo "完成。重启 opencode / Claude Code 后即可使用。"