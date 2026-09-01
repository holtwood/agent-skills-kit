#!/usr/bin/env bash
#
# 一键同步 archify skill 到官方最新版（tt-a1i/archify，MIT）
#
# 流程：拉取官方更新清单 → 下载对应 release 资产 archify.zip →
#       校验官方清单 sha256 → 解压 → 验证 doctor → 备份并替换 skills/archify/
#
# 用法:
#   ./scripts/update-archify.sh          # 同步到最新版
#   ./scripts/update-archify.sh --check  # 只检查是否有新版本，不更新
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL_DIR="${REPO_DIR}/skills/archify"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

MANIFEST_URL="https://tt-a1i.github.io/archify/skill-updates/archify/stable.json"
MANIFEST="${TMP}/stable.json"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "✗ 缺少依赖: $1" >&2
    echo "  请安装后重试（如 apt install unzip / python3）" >&2
    exit 1
  }
}
require_cmd curl
require_cmd unzip
require_cmd python3
require_cmd node

echo "→ 获取官方更新清单 ..."
curl -fsSL "${MANIFEST_URL}" -o "${MANIFEST}"

VERSION="$(python3 -c "import json;print(json.load(open('${MANIFEST}'))['version'])")"
REF="$(python3 -c "import json;print(json.load(open('${MANIFEST}'))['source']['ref'])")"
ARTIFACT_SHA="$(python3 -c "import json;print(json.load(open('${MANIFEST}'))['artifact']['sha256'])")"

if [[ -f "${SKILL_DIR}/skill-release.json" ]]; then
  CURRENT="$(python3 -c "import json;print(json.load(open('${SKILL_DIR}/skill-release.json'))['version'])")"
else
  CURRENT="(未安装)"
fi

echo "  官方最新版: ${VERSION} (${REF})"
echo "  仓库当前版: ${CURRENT}"

if [[ "${CURRENT}" == "${VERSION}" ]]; then
  echo "✓ 已是最新版，无需更新"
  exit 0
fi

if [[ "${1:-}" == "--check" ]]; then
  echo "→ 有新版本 ${VERSION} 可用，运行 ./scripts/update-archify.sh 更新"
  exit 0
fi

ZIP="${TMP}/archify.zip"
ZIP_URL="https://github.com/tt-a1i/archify/releases/download/${REF}/archify.zip"
echo "→ 下载 ${ZIP_URL} ..."
curl -fsSL "${ZIP_URL}" -o "${ZIP}"

echo "→ 校验 sha256（与官方清单比对）..."
echo "${ARTIFACT_SHA}  ${ZIP}" | sha256sum -c - >/dev/null || {
  echo "✗ sha256 校验失败，已中止（可能是下载损坏或清单被篡改）" >&2
  exit 1
}

echo "→ 解压并验证新版本 ..."
unzip -q "${ZIP}" -d "${TMP}"
node "${TMP}/archify/bin/archify.mjs" doctor >/dev/null 2>&1 || {
  echo "✗ 新版 doctor 校验失败，已中止（仓库内容保持不变）" >&2
  exit 1
}

echo "→ 备份并替换 skills/archify/ ..."
if [[ -d "${SKILL_DIR}" ]]; then
  mv "${SKILL_DIR}" "${TMP}/archify.old"
fi
mv "${TMP}/archify" "${SKILL_DIR}"

echo "✓ archify 已更新到 ${VERSION}（${REF}）"
echo "  请检查 git diff 后提交；旧版备份位于 ${TMP}/archify.old（本脚本结束前会自动清理）"
