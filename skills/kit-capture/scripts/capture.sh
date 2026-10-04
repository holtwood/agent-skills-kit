#!/usr/bin/env bash
#
# kit-capture — 跨平台截图（Windows / macOS / Linux / WSL，多后端自动降级）
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
# 平台约定：Windows 上需 Git Bash / MSYS2 环境运行本脚本（底层仍调 powershell.exe）
#
set -uo pipefail

OUT_DIR="${HOME}/Pictures/shotkit"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

have() { command -v "$1" >/dev/null 2>&1; }

# ---------- 平台探测 ----------
UNAME_S="$(uname -s)"
case "${UNAME_S}" in
  Darwin*)              PLATFORM="macos" ;;
  MINGW*|MSYS*|CYGWIN*) PLATFORM="windows" ;;
  Linux*)
    if [[ -n "${WSL_DISTRO_NAME:-}${WSL_INTEROP:-}" ]] || grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then
      PLATFORM="wsl"
    else
      PLATFORM="linux"
    fi ;;
  *) PLATFORM="unknown" ;;
esac

# ---------- Windows 侧工具 ----------
# 路径转换：WSL 用 wslpath，Git Bash/MSYS 用 cygpath
to_win_path() {
  if have wslpath;   then wslpath -w "$1" 2>/dev/null || echo "$1"
  elif have cygpath; then cygpath -w "$1"
  else echo "$1"; fi
}

# 传给 Windows 原生进程（powershell.exe / chrome.exe / node.exe）的路径参数。
# MSYS 只自动转换独立的路径参数，--flag=/path 内嵌形式不会转，必须显式转。
winify() {
  if [[ "${PLATFORM}" == "windows" ]] && have cygpath; then cygpath -w "$1"; else echo "$1"; fi
}

# Windows 侧 PowerShell：WSL interop 与 Git Bash 下都叫 powershell.exe；pwsh 也认
PS_BIN=""
detect_ps() {
  [[ -n "${PS_BIN}" ]] && return 0
  local b
  for b in powershell.exe pwsh powershell; do
    have "$b" && { PS_BIN="$b"; return 0; }
  done
  return 1
}

# ---------- Chromium 自举缓存（kit-shotframe 的探测逻辑也会复用） ----------
# chrome-headless-shell 分平台构建：linux64 / win64 / mac-x64 / mac-arm64
chs_flavor() {
  case "${PLATFORM}" in
    linux|wsl) echo "linux64" ;;
    windows)   echo "win64" ;;
    macos)     [[ "$(uname -m)" == "arm64" ]] && echo "mac-arm64" || echo "mac-x64" ;;
    *)         return 1 ;;
  esac
}
CHS_FLAVOR="$(chs_flavor 2>/dev/null || true)"
CHS_HOME="${XDG_CACHE_HOME:-${HOME}/.cache}/kit-capture/chrome-headless-shell"
CHS_EXE="chrome-headless-shell"
[[ "${PLATFORM}" == "windows" ]] && CHS_EXE="chrome-headless-shell.exe"
CHS_BIN="${CHS_HOME}/chrome-headless-shell-${CHS_FLAVOR}/${CHS_EXE}"
# last-known-good-versions.json 取不到时的回退版本（真实存在过的 Stable）
CHS_FALLBACK_VER="140.0.7339.80"

# ---------- Chromium 探测（与 kit-shotframe 一致） ----------
find_chromium() {
  local v="${KIT_SHOTFRAME_CHROMIUM:-${CHROME_PATH:-}}"
  # Windows 用户可能把变量设成 C:\... 原生路径，先归一成 POSIX 再测
  if [[ "${PLATFORM}" == "windows" && -n "${v}" ]]; then v="$(cygpath -u "${v}" 2>/dev/null || echo "${v}")"; fi
  if [[ -n "${v}" && -x "${v}" ]]; then echo "${v}"; return; fi
  local c r rel
  case "${PLATFORM}" in
    macos)
      for c in \
        "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
        "/Applications/Chromium.app/Contents/MacOS/Chromium" \
        "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge" \
        "${HOME}/Library/Caches/ms-playwright"/chromium-*/chrome-mac*/Chromium.app/Contents/MacOS/Chromium \
        /opt/homebrew/bin/chromium /usr/local/bin/chromium; do
        [[ -x "${c}" ]] && { echo "${c}"; return; }
      done
      ;;
    windows)
      # 环境变量里是 Windows 风格路径（C:\...），且变量名大小写不定
      #（ProgramFiles / PROGRAMFILES 两种写法都常见），用 env|grep -i 按名取
      local -a roots=()
      local e val lapp=""
      for e in PROGRAMFILES LOCALAPPDATA 'PROGRAMFILES(X86)'; do
        val="$(env | grep -i "^${e}=" | head -1 | cut -d= -f2-)"
        [[ -n "${val}" ]] || continue
        val="$(cygpath -u "${val}" 2>/dev/null || echo "${val}")"
        roots+=("${val}")
        [[ "${e}" == "LOCALAPPDATA" ]] && lapp="${val}"
      done
      for r in ${roots[@]+"${roots[@]}"}; do
        for rel in \
          "Google/Chrome/Application/chrome.exe" \
          "Chromium/Application/chrome.exe" \
          "Microsoft/Edge/Application/msedge.exe"; do
          c="${r}/${rel}"
          [[ -f "${c}" ]] && { echo "${c}"; return; }
        done
      done
      for c in "${lapp:-/nonexistent}/ms-playwright"/chromium-*/chrome-win*/chrome.exe; do
        [[ -f "${c}" ]] && { echo "${c}"; return; }
      done
      ;;
    *)  # linux / wsl / 其他 unix 系
      for c in \
        "${HOME}/.cache/ms-playwright"/chromium-*/chrome-linux64/chrome \
        "${HOME}/.cache/ms-playwright"/chromium-*/chrome-linux/chrome \
        /usr/bin/chromium /usr/bin/chromium-browser /usr/bin/google-chrome \
        /usr/bin/google-chrome-stable /usr/bin/chrome /snap/bin/chromium; do
        [[ -x "${c}" ]] && { echo "${c}"; return; }
      done
      ;;
  esac
  # PATH 里的系统浏览器优先于自举缓存（无头壳能力弱于完整 Chrome，能不用就不用）
  # 注意不能直接 `| head -1 && return`：head 对空输入也返回 0，会带着空串提前 return
  c="$(command -v chromium chromium-browser google-chrome google-chrome-stable chrome \
    chrome.exe msedge.exe chromium.exe 2>/dev/null | head -1)"
  [[ -n "${c}" ]] && { echo "${c}"; return; }
  # 共享自举缓存：上次 browser/interact 下载的 chrome-headless-shell
  [[ -x "${CHS_BIN}" ]] && { echo "${CHS_BIN}"; return; }
}

fetch_text() {
  if have curl; then curl -fsSL "$1"
  elif have wget; then wget -qO- "$1"
  else return 1; fi
}
fetch_to() {
  if have curl; then curl -fSL "$1" -o "$2"
  elif have wget; then wget -qO "$2" "$1"
  else return 1; fi
}

ensure_headless_shell() {
  [[ -x "${CHS_BIN}" ]] && { echo "${CHS_BIN}"; return 0; }
  [[ -n "${CHS_FLAVOR}" ]] || { echo "✗ 未识别的平台（${UNAME_S}），无法自举下载" >&2; return 1; }
  have curl || have wget || { echo "✗ 自举下载需要 curl 或 wget" >&2; return 1; }

  echo "⚙ 未找到 Chromium，正在下载 chrome-headless-shell 到 ${CHS_HOME}（约 100MB，仅首次）..." >&2
  local ver
  ver="$(fetch_text "https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions.json" 2>/dev/null \
    | sed -n 's/.*"Stable":{[^}]*"version":"\([0-9.]*\)".*/\1/p')"
  [[ -n "${ver}" ]] || ver="${CHS_FALLBACK_VER}"

  mkdir -p "${CHS_HOME}"
  local zip="${CHS_HOME}/chs.zip"
  if ! fetch_to "https://storage.googleapis.com/chrome-for-testing-public/${ver}/${CHS_FLAVOR}/chrome-headless-shell-${CHS_FLAVOR}.zip" "${zip}"; then
    echo "✗ 下载失败（版本 ${ver}，平台 ${CHS_FLAVOR}）" >&2; rm -f "${zip}"; return 1
  fi
  if have unzip; then
    unzip -q -o "${zip}" -d "${CHS_HOME}" || { rm -f "${zip}"; return 1; }
  elif have python3; then
    python3 -c 'import zipfile,sys; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])' "${zip}" "${CHS_HOME}" || { rm -f "${zip}"; return 1; }
  elif have python; then
    python -c 'import zipfile,sys; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])' "${zip}" "${CHS_HOME}" || { rm -f "${zip}"; return 1; }
  elif detect_ps; then
    # Windows Git Bash 常无 unzip/python，PowerShell Expand-Archive 兜底
    "${PS_BIN}" -NoProfile -Command \
      "Expand-Archive -Force -LiteralPath '$(to_win_path "${zip}")' -DestinationPath '$(to_win_path "${CHS_HOME}")'" \
      || { rm -f "${zip}"; return 1; }
  else
    echo "✗ 解压需要 unzip / python / PowerShell 之一" >&2; rm -f "${zip}"; return 1
  fi
  rm -f "${zip}"
  chmod +x "${CHS_BIN}" 2>/dev/null
  if [[ -x "${CHS_BIN}" ]] || { [[ "${PLATFORM}" == "windows" ]] && [[ -f "${CHS_BIN}" ]]; }; then
    echo "${CHS_BIN}"; return 0
  fi
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
    echo "✗ 未找到 Chromium 且自举下载失败。请安装本机 Chrome/Chromium 或设置 KIT_SHOTFRAME_CHROMIUM" >&2
    return 1
  fi

  # chrome-headless-shell 本身就是无头实现，只认旧版 headless 开关，
  # 传 --headless=new 反而不兼容；常规 Chrome/Chromium 则仍需要它
  local headless_flag="--headless=new"
  case "$(basename "${chromium}")" in *headless-shell*) headless_flag="";; esac

  # 说明：Chromium 命令行没有 --full-page 这类整页截图开关（那是 Puppeteer/Playwright
  # 的 API），整页截图需走 CDP，本 skill 只做视口截图，宽度用 --width 控制
  "${chromium}" ${headless_flag} --disable-gpu --no-sandbox --hide-scrollbars \
    --window-size="${width},1200" --screenshot="$(winify "${out}")" \
    "${url}" >/dev/null 2>&1 || return 1

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
RT_HOME="${XDG_CACHE_HOME:-${HOME}/.cache}/kit-capture/runtime"

ensure_runtime() {
  [[ -d "${RT_HOME}/node_modules/puppeteer-core" ]] && return 0
  have node || { echo "✗ interact 模式需要 Node.js" >&2; return 1; }
  have npm  || { echo "✗ interact 模式需要 npm" >&2; return 1; }
  mkdir -p "${RT_HOME}"
  [[ -f "${RT_HOME}/package.json" ]] || printf '{"name":"kit-capture-runtime","private":true}\n' > "${RT_HOME}/package.json"
  echo "⚙ 安装 puppeteer-core 到 ${RT_HOME}（仅首次，约几 MB，不含浏览器本体）..." >&2
  npm --prefix "$(winify "${RT_HOME}")" install 'puppeteer-core@^24' --no-fund --no-audit --loglevel=error >&2 || return 1
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
    echo "✗ 未找到 Chromium 且自举下载失败。请安装本机 Chrome/Chromium 或设置 KIT_SHOTFRAME_CHROMIUM" >&2
    return 1
  fi
  ensure_runtime || { echo "✗ 剧本运行时安装失败（需要网络 + npm）" >&2; return 1; }

  local -a argv=(--rt "$(winify "${RT_HOME}")" --chromium "$(winify "${chromium}")" --url "${url}" --out "$(winify "${out}")"
    --width "${width}" --height "${height}" --dsf "${dsf}")
  [[ -n "${selector}" ]] && argv+=(--selector "${selector}")
  [[ -n "${fullpage}" ]] && argv+=(--fullpage)
  local a
  for a in ${acts[@]+"${acts[@]}"}; do argv+=(--act "${a}"); done

  if node "$(winify "${SCRIPT_DIR}/interact.cjs")" "${argv[@]}" && [[ -s "${out}" ]]; then
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

  # 后端 1（wsl / windows）：Windows 桌面（PowerShell .NET 全屏捕获）
  if [[ "${PLATFORM}" == "wsl" || "${PLATFORM}" == "windows" ]] && detect_ps; then
    local win_path
    win_path="$(to_win_path "${out}")"
    local win_path_ps="${win_path//\'/\'\'}"
    local ps_code="Add-Type -AssemblyName System.Windows.Forms;
      \$b = [System.Windows.Forms.SystemInformation]::VirtualScreen;
      \$bmp = New-Object System.Drawing.Bitmap \$b.Width, \$b.Height;
      \$g = [System.Drawing.Graphics]::FromImage(\$bmp);
      \$g.CopyFromScreen(\$b.X, \$b.Y, 0, 0, \$bmp.Size);
\$bmp.Save('${win_path_ps}', [System.Drawing.Imaging.ImageFormat]::Png)"
    if "${PS_BIN}" -NoProfile -STA -Command "${ps_code}" >/dev/null 2>&1 && [[ -s "${out}" ]]; then
      echo "✅ Windows 桌面截图: ${out}"
      return 0
    fi
    echo "⚠ PowerShell 截图失败，尝试其他后端..." >&2
  fi

  # 后端 2（macos）：原生 screencapture
  if [[ "${PLATFORM}" == "macos" ]] && have screencapture; then
    if screencapture -x "${out}" 2>/dev/null && [[ -s "${out}" ]]; then
      echo "✅ macOS 桌面截图: ${out}"
      return 0
    fi
    echo "⚠ screencapture 失败（可能缺「屏幕录制」权限），尝试其他后端..." >&2
  fi

  # 后端 3：Wayland（grim，WSLg 与 Linux 桌面通用）
  if have grim && [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    grim "${out}" 2>/dev/null && [[ -s "${out}" ]] && { echo "✅ Wayland 截图: ${out}"; return 0; }
  fi

  # 后端 4：X11（import 存在但执行失败时仍要试 scrot，不能用 elif 只判存在性）
  if have import; then
    import -window root "${out}" 2>/dev/null && [[ -s "${out}" ]] && { echo "✅ X11 截图: ${out}"; return 0; }
  fi
  if have scrot; then
    scrot "${out}" 2>/dev/null && [[ -s "${out}" ]] && { echo "✅ X11 截图: ${out}"; return 0; }
  fi

  # 后端 5：GNOME（gnome-screenshot 在 X11/Wayland 都能走门户）
  if have gnome-screenshot; then
    gnome-screenshot -f "${out}" 2>/dev/null && [[ -s "${out}" ]] && { echo "✅ GNOME 截图: ${out}"; return 0; }
  fi

  case "${PLATFORM}" in
    windows|wsl) echo "✗ 所有截图后端都失败：请确认 powershell.exe 可用（WSL 需开启 interop）" >&2 ;;
    macos)       echo "✗ 所有截图后端都失败：请检查终端的「屏幕录制」权限（系统设置 → 隐私与安全性）" >&2 ;;
    *)           echo "✗ 所有截图后端都失败：请安装 grim（Wayland）或 scrot / imagemagick / gnome-screenshot（X11）之一" >&2 ;;
  esac
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

  # 后端 1（wsl / windows）：PowerShell 找窗口 → CopyFromScreen
  if [[ "${PLATFORM}" == "wsl" || "${PLATFORM}" == "windows" ]]; then
    detect_ps || { echo "✗ window 模式需要 Windows 侧 PowerShell" >&2; return 1; }
    local win_path
    win_path="$(to_win_path "${out}")"
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

    if "${PS_BIN}" -NoProfile -STA -Command "${ps_code}" >/dev/null 2>&1 && [[ -s "${out}" ]]; then
      echo "✅ 窗口截图: ${out} (${query})"
      return 0
    fi
    echo "✗ 未找到窗口或截图失败: ${query}" >&2
    return 1
  fi

  # 后端 2（macos）：JXA 查 CGWindowID（按进程名/窗口标题子串）→ screencapture -l
  if [[ "${PLATFORM}" == "macos" ]]; then
    have osascript && have screencapture || { echo "✗ window 模式需要 osascript + screencapture" >&2; return 1; }
    local wid
    wid="$(osascript -l JavaScript -e '
function run(argv) {
  ObjC.import("CoreGraphics");
  var q = String(argv[0]).toLowerCase();
  var wins = ObjC.deepUnwrap($.CGWindowListCopyWindowInfo($.kCGWindowListOptionOnScreenOnly, 0)) || [];
  for (var i = 0; i < wins.length; i++) {
    var w = wins[i];
    if (w.kCGWindowLayer !== 0) continue;
    var owner = String(w.kCGWindowOwnerName || "").toLowerCase();
    var title = String(w.kCGWindowName || "").toLowerCase();
    if (owner.indexOf(q) >= 0 || title.indexOf(q) >= 0) return String(w.kCGWindowNumber);
  }
  return "";
}' "${query}" 2>/dev/null)"
    if [[ -n "${wid}" ]] && screencapture -x -o -l"${wid}" "${out}" 2>/dev/null && [[ -s "${out}" ]]; then
      echo "✅ 窗口截图: ${out} (${query})"
      return 0
    fi
    echo "✗ 未找到窗口或截图失败: ${query}（确认窗口名；首次使用需授予终端「屏幕录制」权限）" >&2
    return 1
  fi

  # 后端 3（linux X11）：xdotool 按标题找窗口 → ImageMagick import
  if [[ -z "${WAYLAND_DISPLAY:-}" || -n "${DISPLAY:-}" ]]; then
    if have xdotool && have import; then
      local wid
      wid="$(xdotool search --name "${query}" 2>/dev/null | head -1)"
      if [[ -n "${wid}" ]] && import -window "${wid}" "${out}" 2>/dev/null && [[ -s "${out}" ]]; then
        echo "✅ 窗口截图: ${out} (${query})"
        return 0
      fi
    fi
    echo "✗ X11 窗口截图失败：需要 xdotool + imagemagick（sudo apt install xdotool imagemagick），且窗口标题要匹配" >&2
    return 1
  fi

  # Wayland：协议层面没有「按名字截窗口」的接口，只能交互框选（slurp）——不做
  echo "✗ Wayland 下不支持按名称截窗口（协议限制）。请改用 screen 截整屏后裁切，或把目标内容放进浏览器用 browser/interact 截" >&2
  return 1
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

  # 后端 1（wsl / windows）：Windows 剪贴板（PowerShell 直接读，绕过 WSLg BMP 坏图）
  if [[ "${PLATFORM}" == "wsl" || "${PLATFORM}" == "windows" ]] && detect_ps; then
    local win_path win_path_ps
    win_path="$(to_win_path "${out}")"
    # PowerShell 单引号字符串内转义单引号（' -> ''），与 screen/window 模式保持一致
    win_path_ps="${win_path//\'/\'\'}"
    local ps_code="Add-Type -AssemblyName System.Windows.Forms;
      \$img = [System.Windows.Forms.Clipboard]::GetImage();
      if (\$img) { \$img.Save('${win_path_ps}', [System.Drawing.Imaging.ImageFormat]::Png); 'ok' } else { throw 'clipboard empty' }"
    if "${PS_BIN}" -NoProfile -STA -Command "${ps_code}" >/dev/null 2>&1 && [[ -s "${out}" ]]; then
      echo "✅ 剪贴板截图: ${out}"
      return 0
    fi
  fi

  # 后端 2（macos）：osascript 读剪贴板 PNGf；拿不到 PNG 时退 TIFF + sips 转换（全部自带零依赖）
  if [[ "${PLATFORM}" == "macos" ]] && have osascript; then
    if osascript - "${out}" >/dev/null 2>&1 <<'OSA' && [[ -s "${out}" ]]; then
on run argv
  set outPath to item 1 of argv
  set d to the clipboard as «class PNGf»
  set fp to open for access (POSIX file outPath) with write permission
  set eof fp to 0
  write d to fp
  close access fp
end run
OSA
      echo "✅ 剪贴板截图: ${out}"
      return 0
    fi
    # 剪贴板只有 TIFF 时：先写 .tiff 再用系统自带 sips 转 PNG
    if osascript - "${out}.tiff" >/dev/null 2>&1 <<'OSA' && [[ -s "${out}.tiff" ]]; then
on run argv
  set outPath to item 1 of argv
  set d to the clipboard as «class TIFF»
  set fp to open for access (POSIX file outPath) with write permission
  set eof fp to 0
  write d to fp
  close access fp
end run
OSA
      if have sips && sips -s format png "${out}.tiff" --out "${out}" >/dev/null 2>&1 && [[ -s "${out}" ]]; then
        rm -f "${out}.tiff"
        echo "✅ 剪贴板截图 (TIFF 已转换): ${out}"
        return 0
      fi
      rm -f "${out}.tiff"
    fi
  fi

  # 后端 3：Wayland 剪贴板（wl-paste，WSLg 与 Linux 桌面通用；处理 BMP→PNG）
  if have wl-paste && [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    if wl-paste --type image/png > "${out}" 2>/dev/null && [[ -s "${out}" ]]; then
      echo "✅ 剪贴板截图 (Wayland PNG): ${out}"
      return 0
    fi
    # WSLg 常见 BMP 情况
    if wl-paste --type image/bmp > "${out}.bmp" 2>/dev/null && [[ -s "${out}.bmp" ]]; then
      if have convert && convert "${out}.bmp" "${out}" && [[ -s "${out}" ]]; then
        rm -f "${out}.bmp"
        echo "✅ 剪贴板截图 (BMP 已转换): ${out}"
        return 0
      fi
      echo "✗ 剪贴板是 BMP 且无法转换为 PNG（需要 ImageMagick 的 convert）" >&2
      echo "  原始 BMP 保留在: ${out}.bmp（kit-shotframe 只接受 PNG，请勿直接使用）" >&2
      return 1
    fi
  fi

  # 后端 4：X11 剪贴板（xclip）
  if have xclip && [[ -n "${DISPLAY:-}" ]]; then
    if xclip -selection clipboard -t TARGETS -o 2>/dev/null | grep -q 'image/png'; then
      if xclip -selection clipboard -t image/png -o > "${out}" 2>/dev/null && [[ -s "${out}" ]]; then
        echo "✅ 剪贴板截图 (X11 PNG): ${out}"
        return 0
      fi
    elif xclip -selection clipboard -t image/bmp -o > "${out}.bmp" 2>/dev/null && [[ -s "${out}.bmp" ]]; then
      if have convert && convert "${out}.bmp" "${out}" && [[ -s "${out}" ]]; then
        rm -f "${out}.bmp"
        echo "✅ 剪贴板截图 (BMP 已转换): ${out}"
        return 0
      fi
      rm -f "${out}.bmp"
    fi
  fi

  case "${PLATFORM}" in
    windows|wsl) echo "✗ 剪贴板中没有可读的图片（WSL 需开启 interop 或 WSLg）" >&2 ;;
    macos)       echo "✗ 剪贴板中没有可读的图片" >&2 ;;
    *)           echo "✗ 剪贴板中没有可读的图片（或缺少剪贴板工具：装 wl-paste / xclip）" >&2 ;;
  esac
  return 1
}

# ---------- 参数预检：任何无效输入均在探测/下载之前失败 ----------
usage() {
  sed -n '3,14p' "$0"
}
mode="${1:-}"
case "$mode" in -h|--help) usage; exit 0 ;; esac
case "$mode" in browser|interact|screen|window|clip) ;; *) usage >&2; exit 2 ;; esac
shift
validated_args=()
FINAL_OUT=""
POSITIONAL=0
while [[ $# -gt 0 ]]; do
  flag="$1"
  case "$flag" in
    -h|--help) usage; exit 0 ;;
    --fullpage)
      [[ "$mode" == interact ]] || { echo "✗ $mode 不支持 $flag" >&2; exit 2; }
      validated_args+=("$flag"); shift ;;
    -o|--output|--width|--height|--dsf|--selector|--sel|--click|--wait|--waitfor|--scroll)
      [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || { echo "✗ $flag 缺少参数" >&2; exit 2; }
      value="$2"
      case "$flag" in
        -o|--output) FINAL_OUT="$value" ;;
        --width)
          [[ "$mode" == browser || "$mode" == interact ]] || { echo "✗ $mode 不支持 $flag" >&2; exit 2; }
          [[ "$value" =~ ^[0-9]{1,5}$ ]] && (( 10#$value > 0 && 10#$value <= 16000 )) || { echo '✗ width 必须为 1..16000 的整数' >&2; exit 2; }
          validated_args+=("$flag" "$value") ;;
        *)
          [[ "$mode" == interact ]] || { echo "✗ $mode 不支持 $flag" >&2; exit 2; }
          case "$flag" in
            --height) [[ "$value" =~ ^[0-9]{1,5}$ ]] && (( 10#$value > 0 && 10#$value <= 16000 )) || { echo '✗ height 必须为 1..16000 的整数' >&2; exit 2; } ;;
            --dsf) [[ "$value" =~ ^[0-9]+([.][0-9]+)?$ ]] && awk -v n="$value" 'BEGIN { exit !(n>0 && n<=8) }' || { echo '✗ dsf 必须在 (0,8] 内' >&2; exit 2; } ;;
            --wait) [[ "$value" =~ ^[0-9]{1,5}$ ]] && (( 10#$value <= 60000 )) || { echo '✗ wait 必须为 0..60000 毫秒' >&2; exit 2; } ;;
            --scroll) [[ "$value" =~ ^-?[0-9]{1,6}$ ]] || { echo '✗ scroll 必须为整数像素' >&2; exit 2; } ;;
          esac
          validated_args+=("$flag" "$value") ;;
      esac
      shift 2 ;;
    -*) echo "✗ 未知参数: $flag" >&2; exit 2 ;;
    *)
      [[ "$mode" == browser || "$mode" == interact || "$mode" == window ]] && [[ "$POSITIONAL" -eq 0 ]] || { echo "✗ 多余参数: $flag" >&2; exit 2; }
      POSITIONAL=1; validated_args+=("$flag"); shift ;;
  esac
done
if [[ "$mode" == browser || "$mode" == interact || "$mode" == window ]]; then
  [[ "$POSITIONAL" -eq 1 ]] || { echo "✗ $mode 缺少目标参数" >&2; exit 2; }
fi
FINAL_OUT="${FINAL_OUT:-${OUT_DIR}/${mode}-$(date +%Y%m%d-%H%M%S).png}"
mkdir -p "$(dirname "$FINAL_OUT")" || exit 1
STAGE_DIR="$(mktemp -d "$(dirname "$FINAL_OUT")/.kit-capture.XXXXXX")" || exit 1
trap 'rm -f "$STAGE_DIR/shot.png" "$STAGE_DIR/shot.png.bmp" "$STAGE_DIR/shot.png.tiff"; rmdir "$STAGE_DIR"' EXIT
validated_args+=(-o "$STAGE_DIR/shot.png")
run_capture() {
  case "$mode" in
    browser) cmd_browser "${validated_args[@]}" ;;
    interact) cmd_interact "${validated_args[@]}" ;;
    screen) cmd_screen "${validated_args[@]}" ;;
    window) cmd_window "${validated_args[@]}" ;;
    clip) cmd_clip "${validated_args[@]}" ;;
  esac
}
if run_capture >/dev/null && [[ -s "$STAGE_DIR/shot.png" ]]; then
  signature="$(od -An -tx1 -N8 "$STAGE_DIR/shot.png" | tr -d ' \n')"
  [[ "$signature" == 89504e470d0a1a0a ]] || { echo '✗ 后端未输出 PNG，原文件已保留' >&2; exit 1; }
  mv "$STAGE_DIR/shot.png" "$FINAL_OUT" || exit 1
  echo "✅ ${mode} 截图: $FINAL_OUT"
else
  if [[ -s "$STAGE_DIR/shot.png.bmp" ]]; then mv "$STAGE_DIR/shot.png.bmp" "$FINAL_OUT.bmp"; echo "原始 BMP: $FINAL_OUT.bmp" >&2; fi
  echo "✗ $mode 截图失败，原文件已保留" >&2
  exit 1
fi
