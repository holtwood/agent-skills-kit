#!/usr/bin/env bash
#
# wsl-capture — WSL 环境截图（多后端自动降级）
#
# 用法:
#   capture.sh browser <url> [-o out.png] [--width 1440] [--full-page]
#   capture.sh screen  [-o out.png]
#   capture.sh window  <标题或进程名> [-o out.png]
#   capture.sh clip    [-o out.png]
#
set -uo pipefail

OUT_DIR="${HOME}/Pictures/shotkit"
mkdir -p "${OUT_DIR}"

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

# ---------- 模式: browser ----------
cmd_browser() {
  local url="" out="" width="1440" full_page=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -o|--output) out="$2"; shift 2 ;;
      --width) width="$2"; shift 2 ;;
      --full-page) full_page=1; shift ;;
      -*) echo "未知参数: $1" >&2; exit 2 ;;
      *) url="$1"; shift ;;
    esac
  done
  [[ -z "${url}" ]] && { echo "用法: capture.sh browser <url> [-o out.png] [--width 1440] [--full-page]" >&2; exit 2; }
  out="${out:-${OUT_DIR}/browser-$(date +%H%M%S).png}"

  local chromium
  chromium="$(find_chromium)" || true
  if [[ -z "${chromium}" ]]; then
    echo "✗ 未找到 Chromium，请安装（sudo apt install chromium）或设置 SHOTFRAME_CHROMIUM" >&2
    return 1
  fi

  local flag_full=""
  [[ "${full_page}" -eq 1 ]] && flag_full="--full-page"
  # shellcheck disable=SC2086
  "${chromium}" --headless=new --disable-gpu --no-sandbox --hide-scrollbars \
    --window-size="${width},1200" --screenshot="${out}" ${flag_full} \
    "${url}" >/dev/null 2>&1

  if [[ -s "${out}" ]]; then
    echo "✅ 网页截图: ${out}"
  else
    echo "✗ 网页截图失败: ${url}" >&2
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
  # 按标题找窗口 → 用 Win32 API 截到前台应用窗口
  local ps_code="Add-Type -AssemblyName System.Drawing;
    Add-Type @'
    using System;
    using System.Runtime.InteropServices;
    public class W {
      [DllImport(\"user32.dll\")] public static extern IntPtr FindWindow(string c, string t);
      [DllImport(\"user32.dll\")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
      [DllImport(\"user32.dll\")] public static extern bool SetForegroundWindow(IntPtr h);
      public struct RECT { public int L, T, R, B; }
    }
'@;
    \$h = [W]::FindWindow(\$null, '${query_ps}');
    if (\$h -eq [IntPtr]::Zero) { throw 'window not found' };
    [W]::SetForegroundWindow(\$h) | Out-Null;
    Start-Sleep -Milliseconds 300;
    \$r = New-Object W+RECT;
    [W]::GetWindowRect(\$h, [ref]\$r) | Out-Null;
    \$w = \$r.R - \$r.L; \$hgt = \$r.B - \$r.T;
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
    local win_path
    win_path="$(wslpath -w "${out}" 2>/dev/null || echo "${out}")"
    local ps_code="Add-Type -AssemblyName System.Windows.Forms;
      \$img = [System.Windows.Forms.Clipboard]::GetImage();
      if (\$img) { \$img.Save('${win_path}', [System.Drawing.Imaging.ImageFormat]::Png); 'ok' } else { throw 'clipboard empty' }"
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
[[ -z "${mode}" ]] && { echo "用法: capture.sh <browser|screen|window|clip> [参数...]" >&2; exit 2; }
shift
case "${mode}" in
  browser) cmd_browser "$@" ;;
  screen)  cmd_screen "$@" ;;
  window)  cmd_window "$@" ;;
  clip)    cmd_clip "$@" ;;
  *) echo "未知模式: ${mode}（支持 browser / screen / window / clip）" >&2; exit 2 ;;
esac