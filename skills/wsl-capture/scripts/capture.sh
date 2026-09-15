#!/usr/bin/env bash
#
# wsl-capture — WSL 环境截图（多后端自动降级）
#
# 用法:
#   capture.sh browser  <url> [-o out.png] [--width 1440]
#   capture.sh interact <url> [-o out.png] [--width 1440] [--height 900] [--dsf 1]
#                       [--selector <css>] [--fullpage]
#                       [--click <css>] [--wait <ms>] [--waitfor <css>] [--scroll <px>]
#   capture.sh screen   [-o out.png]
#   capture.sh window   <标题或进程名> [-o out.png]
#   capture.sh clip     [-o out.png]
#
set -uo pipefail

OUT_DIR="${HOME}/Pictures/shotkit"
mkdir -p "${OUT_DIR}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------- Chromium 探测（与 shotframe 一致） ----------
find_chromium() {
  if [[ -n "${SHOTFRAME_CHROMIUM:-}" && -x "${SHOTFRAME_CHROMIUM}" ]]; then
    echo "${SHOTFRAME_CHROMIUM}"; return
  fi
  for c in \
    "${HOME}/.cache/ms-playwright"/chromium-*/chrome-linux64/chrome \
    "${HOME}/.cache/ms-playwright"/chromium-*/chrome-linux/chrome \
    /usr/bin/chromium /usr/bin/chromium-browser /usr/bin/google-chrome \
    /usr/bin/google-chrome-stable /usr/bin/chrome /snap/bin/chromium; do
    if [[ -x "${c}" ]]; then echo "${c}"; return; fi
  done
  command -v chromium chromium-browser google-chrome chrome 2>/dev/null | head -1
}

# ---------- Chromium 自举：找不到时下载 chrome-headless-shell ----------
# 参考 WholeNightCoding/web-screenshot 的思路：无头壳约 100MB，缓存到
# ~/.cache/wsl-capture/，仅首次需要；shotframe 的探测逻辑也会复用这个缓存
CHS_HOME="${XDG_CACHE_HOME:-${HOME}/.cache}/wsl-capture/chrome-headless-shell"
CHS_BIN="${CHS_HOME}/chrome-headless-shell-linux64/chrome-headless-shell"
# last-known-good-versions.json 取不到时的回退版本（真实存在过的 Stable）
CHS_FALLBACK_VER="140.0.7339.80"

fetch_text() {
  if command -v curl >/dev/null 2>&1; then curl -fsSL "$1"
  elif command -v wget >/dev/null 2>&1; then wget -qO- "$1"
  else return 1; fi
}
fetch_to() {
  if command -v curl >/dev/null 2>&1; then curl -fSL "$1" -o "$2"
  elif command -v wget >/dev/null 2>&1; then wget -qO "$2" "$1"
  else return 1; fi
}

ensure_headless_shell() {
  [[ -x "${CHS_BIN}" ]] && { echo "${CHS_BIN}"; return 0; }
  # 自举包只有 linux64 构建可用——macOS/Git-Bash 上下载也跑不了，直接拒绝
  [[ "$(uname -s)" == "Linux" ]] || { echo "✗ 自举下载仅支持 Linux/WSL；请安装本机 Chromium 或设置 SHOTFRAME_CHROMIUM" >&2; return 1; }
  command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1 || return 1

  echo "⚙ 未找到 Chromium，正在下载 chrome-headless-shell 到 ${CHS_HOME}（约 100MB，仅首次）..." >&2
  local ver
  ver="$(fetch_text "https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions.json" 2>/dev/null \
    | sed -n 's/.*"Stable":{[^}]*"version":"\([0-9.]*\)".*/\1/p')"
  [[ -n "${ver}" ]] || ver="${CHS_FALLBACK_VER}"

  mkdir -p "${CHS_HOME}"
  local zip="${CHS_HOME}/chs.zip"
  if ! fetch_to "https://storage.googleapis.com/chrome-for-testing-public/${ver}/linux64/chrome-headless-shell-linux64.zip" "${zip}"; then
    echo "✗ 下载失败（版本 ${ver}）" >&2; rm -f "${zip}"; return 1
  fi
  if command -v unzip >/dev/null 2>&1; then
    unzip -q -o "${zip}" -d "${CHS_HOME}" || { rm -f "${zip}"; return 1; }
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import zipfile,sys; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])' "${zip}" "${CHS_HOME}" || { rm -f "${zip}"; return 1; }
  else
    echo "✗ 解压需要 unzip 或 python3（sudo apt install unzip）" >&2; rm -f "${zip}"; return 1
  fi
  rm -f "${zip}"
  chmod +x "${CHS_BIN}" 2>/dev/null
  if [[ -x "${CHS_BIN}" ]]; then echo "${CHS_BIN}"; return 0; fi
  echo "✗ 解压后未找到可执行文件: ${CHS_BIN}" >&2
  return 1
}

# ---------- 模式: browser ----------
cmd_browser() {
  local url="" out="" width="1440"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -o|--output) out="$2"; shift 2 ;;
      --width) width="$2"; shift 2 ;;
      -*) echo "未知参数: $1" >&2; exit 2 ;;
      *) url="$1"; shift ;;
    esac
  done
  [[ "${width}" =~ ^[0-9]+$ ]] || { echo "✗ --width 必须是正整数，收到: ${width}" >&2; exit 2; }
  [[ -z "${url}" ]] && { echo "用法: capture.sh browser <url> [-o out.png] [--width 1440]" >&2; exit 2; }
  out="${out:-${OUT_DIR}/browser-$(date +%H%M%S).png}"

  local chromium
  chromium="$(find_chromium)" || true
  # 找不到系统浏览器时自举下载 chrome-headless-shell（缓存复用，仅首次下载）
  if [[ -z "${chromium}" ]]; then
    chromium="$(ensure_headless_shell)" || true
  fi
  if [[ -z "${chromium}" ]]; then
    echo "✗ 未找到 Chromium 且自举下载失败。请安装（sudo apt install chromium）或设置 SHOTFRAME_CHROMIUM" >&2
    return 1
  fi

  # chrome-headless-shell 本身就是无头实现，只认旧版 headless 开关，
  # 传 --headless=new 反而不兼容；常规 Chrome/Chromium 则仍需要它
  local headless_flag="--headless=new"
  case "$(basename "${chromium}")" in *headless-shell*) headless_flag="";; esac

  # 说明：Chromium 命令行没有 --full-page 这类整页截图开关（那是 Puppeteer/Playwright
  # 的 API），整页截图需走 CDP，本 skill 只做视口截图，宽度用 --width 控制
  "${chromium}" ${headless_flag} --disable-gpu --no-sandbox --hide-scrollbars \
    --window-size="${width},1200" --screenshot="${out}" \
    "${url}" >/dev/null 2>&1

  if [[ -s "${out}" ]]; then
    echo "✅ 网页截图: ${out}"
  else
    echo "✗ 网页截图失败: ${url}" >&2
    return 1
  fi
}

# ---------- 模式: interact（剧本化截图，可选增强） ----------
# browser 模式只能"打开即截"。interact 用 puppeteer-core 驱动同一 Chromium：
# 点选择器、等元素、滚动后再截，也可以只截某个元素或整页。
# 代价：首次使用要 npm install puppeteer-core 到缓存目录（非项目依赖）。
RT_HOME="${XDG_CACHE_HOME:-${HOME}/.cache}/wsl-capture/runtime"

ensure_runtime() {
  [[ -d "${RT_HOME}/node_modules/puppeteer-core" ]] && return 0
  command -v node >/dev/null 2>&1 || { echo "✗ interact 模式需要 Node.js" >&2; return 1; }
  command -v npm >/dev/null 2>&1 || { echo "✗ interact 模式需要 npm" >&2; return 1; }
  mkdir -p "${RT_HOME}"
  [[ -f "${RT_HOME}/package.json" ]] || printf '{"name":"wsl-capture-runtime","private":true}\n' > "${RT_HOME}/package.json"
  echo "⚙ 安装 puppeteer-core 到 ${RT_HOME}（仅首次，约几 MB，不含浏览器本体）..." >&2
  npm --prefix "${RT_HOME}" install 'puppeteer-core@^24' --no-fund --no-audit --loglevel=error >&2 || return 1
  [[ -d "${RT_HOME}/node_modules/puppeteer-core" ]]
}

cmd_interact() {
  local url="" out="" width="1440" height="900" dsf="1" selector="" fullpage=""
  local -a acts=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -o|--output) out="$2"; shift 2 ;;
      --width)   width="$2"; shift 2 ;;
      --height)  height="$2"; shift 2 ;;
      --dsf)     dsf="$2"; shift 2 ;;
      --selector|--sel) selector="$2"; shift 2 ;;
      --fullpage) fullpage="1"; shift ;;
      --click)   acts+=("click:$2"); shift 2 ;;
      --wait)    acts+=("wait:$2"); shift 2 ;;
      --waitfor) acts+=("waitfor:$2"); shift 2 ;;
      --scroll)  acts+=("scroll:$2"); shift 2 ;;
      -*) echo "未知参数: $1" >&2; exit 2 ;;
      *) url="$1"; shift ;;
    esac
  done
  [[ -z "${url}" ]] && { echo "用法: capture.sh interact <url> [-o out.png] [--width 1440] [--height 900] [--dsf 1] [--selector <css>] [--fullpage] [--click <css>] [--wait <ms>] [--waitfor <css>] [--scroll <px>]" >&2; exit 2; }
  # 与 browser 模式一致：数值参数在 bash 层校验，错误信息更可读
  for pair in "width:${width}" "height:${height}" "dsf:${dsf}"; do
    local k="${pair%%:*}" v="${pair#*:}"
    [[ "${v}" =~ ^[0-9]+([.][0-9]+)?$ ]] || { echo "✗ --${k} 必须是正数，收到: ${v}" >&2; exit 2; }
  done
  out="${out:-${OUT_DIR}/interact-$(date +%H%M%S).png}"

  local chromium
  chromium="$(find_chromium)" || true
  if [[ -z "${chromium}" ]]; then
    chromium="$(ensure_headless_shell)" || true
  fi
  if [[ -z "${chromium}" ]]; then
    echo "✗ 未找到 Chromium 且自举下载失败。请安装（sudo apt install chromium）或设置 SHOTFRAME_CHROMIUM" >&2
    return 1
  fi
  ensure_runtime || { echo "✗ 剧本运行时安装失败（需要网络 + npm）" >&2; return 1; }

  local -a argv=(--chromium "${chromium}" --url "${url}" --out "${out}"
    --width "${width}" --height "${height}" --dsf "${dsf}")
  [[ -n "${selector}" ]] && argv+=(--selector "${selector}")
  [[ -n "${fullpage}" ]] && argv+=(--fullpage)
  local a
  for a in "${acts[@]}"; do argv+=(--act "${a}"); done

  if NODE_PATH="${RT_HOME}/node_modules" node "${SCRIPT_DIR}/interact.cjs" "${argv[@]}" && [[ -s "${out}" ]]; then
    echo "✅ 剧本截图: ${out}"
  else
    echo "✗ 剧本截图失败: ${url}" >&2
    return 1
  fi
}

# ---------- 模式: screen ----------
cmd_screen() {
  local out=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -o|--output) out="$2"; shift 2 ;;
      *) echo "未知参数: $1" >&2; exit 2 ;;
    esac
  done
  out="${out:-${OUT_DIR}/screen-$(date +%H%M%S).png}"

  # 后端 1: Windows 桌面（PowerShell .NET 全屏捕获）
  if command -v powershell.exe >/dev/null 2>&1; then
    local win_path
    win_path="$(wslpath -w "${out}" 2>/dev/null || echo "${out}")"
    local win_path_ps="${win_path//\'/\'\'}"
    local ps_code="Add-Type -AssemblyName System.Windows.Forms;
      \$b = [System.Windows.Forms.SystemInformation]::VirtualScreen;
      \$bmp = New-Object System.Drawing.Bitmap \$b.Width, \$b.Height;
      \$g = [System.Drawing.Graphics]::FromImage(\$bmp);
      \$g.CopyFromScreen(\$b.X, \$b.Y, 0, 0, \$bmp.Size);
\$bmp.Save('${win_path_ps}', [System.Drawing.Imaging.ImageFormat]::Png)"
    if powershell.exe -NoProfile -STA -Command "${ps_code}" >/dev/null 2>&1 && [[ -s "${out}" ]]; then
      echo "✅ Windows 桌面截图: ${out}"
      return 0
    fi
    echo "⚠ PowerShell 截图失败，尝试 WSLg/X11 后端..." >&2
  fi

  # 后端 2: WSLg Wayland（grim）
  if command -v grim >/dev/null 2>&1 && [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    grim "${out}" 2>/dev/null && [[ -s "${out}" ]] && { echo "✅ WSLg 截图: ${out}"; return 0; }
  fi

  # 后端 3: X11
  if command -v import >/dev/null 2>&1; then
    import -window root "${out}" 2>/dev/null && [[ -s "${out}" ]] && { echo "✅ X11 截图: ${out}"; return 0; }
  elif command -v scrot >/dev/null 2>&1; then
    scrot "${out}" 2>/dev/null && [[ -s "${out}" ]] && { echo "✅ X11 截图: ${out}"; return 0; }
  fi

  echo "✗ 所有截图后端都失败。请安装: sudo apt install scrot imagemagick，或确认 WSLg 运行中" >&2
  return 1
}

# ---------- 模式: window ----------
cmd_window() {
  local query="${1:-}"
  if [[ -z "${query}" ]]; then
    echo "用法: capture.sh window <标题或进程名> [-o out.png]" >&2
    exit 2
  fi
  shift
  local out=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -o|--output) out="$2"; shift 2 ;;
      *) echo "未知参数: $1" >&2; exit 2 ;;
    esac
  done
  out="${out:-${OUT_DIR}/window-$(date +%H%M%S).png}"

  command -v powershell.exe >/dev/null 2>&1 || { echo "✗ window 模式需要 Windows 侧 PowerShell" >&2; return 1; }

  local win_path
  win_path="$(wslpath -w "${out}" 2>/dev/null || echo "${out}")"
  # PowerShell 单引号字符串内转义单引号（' -> ''），防止窗口标题含引号时坏脚本
  local query_ps="${query//\'/\'\'}"
  local win_path_ps="${win_path//\'/\'\'}"
  # 找窗口：标题子串匹配（不分大小写）→ 进程名精确 → 进程名前缀，取首个有主窗口的进程
  local ps_code="Add-Type -AssemblyName System.Drawing;
    Add-Type @'
    using System;
    using System.Runtime.InteropServices;
    public class W {
      [DllImport(\"user32.dll\")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
      [DllImport(\"user32.dll\")] public static extern bool SetForegroundWindow(IntPtr h);
      public struct RECT { public int L, T, R, B; }
    }
'@;
    \$q = '${query_ps}';
    \$p = Get-Process | Where-Object { \$_.MainWindowTitle -and \$_.MainWindowTitle.IndexOf(\$q, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 } | Select-Object -First 1;
    if (-not \$p) { \$p = Get-Process | Where-Object { \$_.MainWindowHandle -ne 0 -and \$_.ProcessName -ieq \$q } | Select-Object -First 1 };
    if (-not \$p) { \$p = Get-Process | Where-Object { \$_.MainWindowHandle -ne 0 -and \$_.ProcessName.StartsWith(\$q, [System.StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1 };
    if (-not \$p) { throw 'window not found' };
    \$h = \$p.MainWindowHandle;
    [W]::SetForegroundWindow(\$h) | Out-Null;
    Start-Sleep -Milliseconds 300;
    \$r = New-Object W+RECT;
    [W]::GetWindowRect(\$h, [ref]\$r) | Out-Null;
    \$w = \$r.R - \$r.L; \$hgt = \$r.B - \$r.T;
    if (\$w -le 0 -or \$hgt -le 0) { throw 'invalid window rect' };
    \$bmp = New-Object System.Drawing.Bitmap \$w, \$hgt;
    \$g = [System.Drawing.Graphics]::FromImage(\$bmp);
    \$g.CopyFromScreen(\$r.L, \$r.T, 0, 0, \$bmp.Size);
    \$bmp.Save('${win_path_ps}', [System.Drawing.Imaging.ImageFormat]::Png)"

  if powershell.exe -NoProfile -STA -Command "${ps_code}" >/dev/null 2>&1 && [[ -s "${out}" ]]; then
    echo "✅ 窗口截图: ${out} (${query})"
  else
    echo "✗ 未找到窗口或截图失败: ${query}" >&2
    return 1
  fi
}

# ---------- 模式: clip ----------
cmd_clip() {
  local out=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -o|--output) out="$2"; shift 2 ;;
      *) echo "未知参数: $1" >&2; exit 2 ;;
    esac
  done
  out="${out:-${OUT_DIR}/clip-$(date +%H%M%S).png}"

  # 后端 1: Windows 剪贴板（PowerShell 直接读，绕过 WSLg BMP 坏图）
  if command -v powershell.exe >/dev/null 2>&1; then
    local win_path win_path_ps
    win_path="$(wslpath -w "${out}" 2>/dev/null || echo "${out}")"
    # PowerShell 单引号字符串内转义单引号（' -> ''），与 screen/window 模式保持一致
    win_path_ps="${win_path//\'/\'\'}"
    local ps_code="Add-Type -AssemblyName System.Windows.Forms;
      \$img = [System.Windows.Forms.Clipboard]::GetImage();
      if (\$img) { \$img.Save('${win_path_ps}', [System.Drawing.Imaging.ImageFormat]::Png); 'ok' } else { throw 'clipboard empty' }"
    if powershell.exe -NoProfile -STA -Command "${ps_code}" >/dev/null 2>&1 && [[ -s "${out}" ]]; then
      echo "✅ 剪贴板截图: ${out}"
      return 0
    fi
  fi

  # 后端 2: WSLg Wayland 剪贴板（wl-paste，处理 BMP→PNG）
  if command -v wl-paste >/dev/null 2>&1 && [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    if wl-paste --type image/png > "${out}" 2>/dev/null && [[ -s "${out}" ]]; then
      echo "✅ 剪贴板截图 (WSLg PNG): ${out}"
      return 0
    fi
    # WSLg 常见 BMP 情况
    if wl-paste --type image/bmp > "${out}.bmp" 2>/dev/null && [[ -s "${out}.bmp" ]]; then
      if command -v convert >/dev/null 2>&1 && convert "${out}.bmp" "${out}" && [[ -s "${out}" ]]; then
        rm -f "${out}.bmp"
        echo "✅ 剪贴板截图 (BMP 已转换): ${out}"
        return 0
      fi
      echo "✗ 剪贴板是 BMP 且无法转换为 PNG（需要 ImageMagick 的 convert）" >&2
      echo "  原始 BMP 保留在: ${out}.bmp（shotframe 只接受 PNG，请勿直接使用）" >&2
      return 1
    fi
  fi

  echo "✗ 剪贴板中没有可读的图片" >&2
  return 1
}

# ---------- 入口 ----------
mode="${1:-}"
[[ -z "${mode}" ]] && { echo "用法: capture.sh <browser|interact|screen|window|clip> [参数...]" >&2; exit 2; }
shift
case "${mode}" in
  browser)  cmd_browser "$@" ;;
  interact) cmd_interact "$@" ;;
  screen)   cmd_screen "$@" ;;
  window)   cmd_window "$@" ;;
  clip)     cmd_clip "$@" ;;
  *) echo "未知模式: ${mode}（支持 browser / interact / screen / window / clip）" >&2; exit 2 ;;
esac