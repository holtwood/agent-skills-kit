#!/usr/bin/env bash
#
# 一键同步 archify skill 到官方最新版（tt-a1i/archify，MIT）
#
# 流程：拉取官方更新清单 → 校验清单字段（channel/version/ref/sha256）→
#       下载对应 release 资产 archify.zip → 校验官方清单 sha256 →
#       检查压缩包条目防路径穿越 → 解压 → 验证 doctor → 替换 skills/archify/（git 兜底）
#
# 安全特性：
#   - 清单字段 cross-validation（channel=stable、ref=v<version>、sha256 为 64 位 hex）
#   - 防降级：本地版本不低于官方最新版时跳过
#   - 覆盖前检查未提交改动；旧版由 git 历史兜底，不另做备份
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

# 校验清单字段：任一不合法即中止（防止篡改/格式错误导致异常 URL 或错误校验）
MANIFEST_INFO="$(python3 - "${MANIFEST}" <<'PY'
import json, re, sys
m = json.load(open(sys.argv[1], encoding='utf-8'))
if not isinstance(m, dict):
    sys.exit('manifest 不是 JSON 对象')
channel = m.get('channel')
version = m.get('version')
ref = (m.get('source') or {}).get('ref')
sha = (m.get('artifact') or {}).get('sha256')
if channel != 'stable':
    sys.exit('manifest channel 不是 stable')
if not isinstance(version, str) or not re.fullmatch(r'\d+\.\d+\.\d+', version):
    sys.exit('manifest version 不是合法 semver')
if ref != 'v' + version:
    sys.exit('manifest source.ref 与 version 不一致')
if not isinstance(sha, str) or not re.fullmatch(r'[a-f0-9]{64}', sha):
    sys.exit('manifest artifact.sha256 不是 64 位 hex')
print(f"{version} {ref} {sha}")
PY
)" || {
  echo "✗ 官方更新清单字段校验失败（channel/version/ref/sha256），已中止" >&2
  exit 1
}
read -r VERSION REF ARTIFACT_SHA <<< "${MANIFEST_INFO}"

CURRENT=""
if [[ -f "${SKILL_DIR}/skill-release.json" ]]; then
  CURRENT="$(python3 -c "import json;print(json.load(open('${SKILL_DIR}/skill-release.json'))['version'])")"
fi

echo "  官方最新版: ${VERSION} (${REF})"
echo "  仓库当前版: ${CURRENT:-（未安装）}"

# 版本比较：已是最新 / 本地更高（防降级）
if [[ -n "${CURRENT}" ]]; then
  if [[ "${CURRENT}" == "${VERSION}" ]]; then
    echo "✓ 已是最新版，无需更新"
    exit 0
  fi
  if python3 -c '
import sys
def key(v): return tuple(int(x) for x in v.split("."))
try:
    sys.exit(0 if key(sys.argv[1]) > key(sys.argv[2]) else 1)
except Exception:
    sys.exit(1)
' "${CURRENT}" "${VERSION}" 2>/dev/null; then
    echo "ℹ 本地版本 ${CURRENT} 高于官方最新版 ${VERSION}，已跳过（防降级）"
    exit 0
  fi
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

echo "→ 检查压缩包条目（防路径穿越）..."
if ! unzip -Z1 "${ZIP}" | python3 -c '
import sys
bad = []
for line in sys.stdin:
    p = line.rstrip("\n")
    if not p or p.startswith("/") or ".." in p or "\\" in p:
        bad.append(p)
if bad:
    print("不安全条目:", bad[:5], file=sys.stderr)
    sys.exit(1)
'; then
  echo "✗ 压缩包包含不安全的路径条目，已中止（仓库内容保持不变）" >&2
  exit 1
fi

echo "→ 解压并验证新版本 ..."
unzip -q "${ZIP}" -d "${TMP}"
node "${TMP}/archify/bin/archify.mjs" doctor >/dev/null 2>&1 || {
  echo "✗ 新版 doctor 校验失败，已中止（仓库内容保持不变）" >&2
  exit 1
}

echo "→ 替换 skills/archify/ ..."
# 覆盖前先确认没有未提交的本地改动（git 历史救不回来，这也是唯一需要保护的）
if git -C "${REPO_DIR}" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  && ! git -C "${REPO_DIR}" diff --quiet -- "${SKILL_DIR}" 2>/dev/null; then
  echo "✗ skills/archify 有未提交的本地改动，已中止（旧版由 git 历史兜底，覆盖前请先提交或 stash）" >&2
  exit 1
fi
if [[ -d "${SKILL_DIR}" ]]; then
  mv "${SKILL_DIR}" "${TMP}/archify.old"
fi
if ! mv "${TMP}/archify" "${SKILL_DIR}"; then
  echo "✗ 替换新版本失败，正在回滚..." >&2
  if [[ -d "${TMP}/archify.old" ]] && mv "${TMP}/archify.old" "${SKILL_DIR}"; then
    echo "  ✓ 已回滚到原版本"
  else
    echo "  ✗ 回滚失败，可用 git restore skills/archify 从 git 历史恢复（旧版在 git 历史中）" >&2
  fi
  exit 1
fi
rm -rf "${TMP}/archify.old"

echo "✓ archify 已更新到 ${VERSION}（${REF}）"
echo "  请检查 git diff 后提交；如需回滚：git restore --source=<旧提交> skills/archify"
