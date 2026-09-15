---
name: "kit-capture"
description: "跨平台截图：Windows（Git Bash）/ macOS / Linux / WSL。截网页（Chromium 无头）、剧本化截图（点按钮/等元素/截元素）、整屏、指定窗口、剪贴板图片。多后端自动降级，找不到 Chromium 时按平台自举下载 chrome-headless-shell。触发场景：'截个屏'、'截这个网页'、'截登录后的页面'、'截某个窗口'、'剪贴板里的图取出来'。"
---

# Kit Capture · 跨平台截图

一个脚本五个模式，各平台自动选后端：

- ✅ 截 **浏览器页面**（Chromium 无头，最稳路径，全平台）
- ✅ **交互后再截**（点按钮、等元素出现、截某个元素/整页——可选增强模式，全平台）
- ✅ 截 **整屏桌面**（Windows / macOS / Linux）
- ✅ 截 **指定窗口**（Windows / macOS / Linux X11）
- ✅ 从 **剪贴板** 取图（Windows / macOS / Linux）

## 何时使用

- 用户想要「当前屏幕 / 某个窗口 / 某个网页」的截图
- 用户要截「登录后的页面 / 点了某个按钮的状态 / 某个组件」这类需要先交互的画面
- 用户提到截图黑屏、剪贴板粘贴坏图
- 截图给 AI 分析、写进文档、或准备交给 `kit-shotframe` 套框

## 何时不要用

- 交互剧本复杂到要录多步流程/断言状态——那是 Playwright 测试的活，本 skill 的 `interact` 只做轻量剧本
- Wayland 桌面下按名称截某个窗口——协议层面做不到，用 `screen` 截整屏后裁切
- Windows 上没有 bash 环境（需 Git Bash / MSYS2；纯 PowerShell 用户直接用系统截图工具）

## 命令契约

```bash
bash <skill目录>/scripts/capture.sh <mode> [参数...]
```

| 模式 | 作用 | 参数 |
| --- | --- | --- |
| `browser <url>` | 截网页（打开即截，视口截图） | `-o 输出.png`、`--width 1440` |
| `interact <url>` | **剧本化截网页**（可选增强，首次用自动装 puppeteer-core 到缓存目录） | `-o 输出.png`、`--width 1440`、`--height 900`、`--dsf 1`、`--selector <css>`（只截该元素）、`--fullpage`（整页）、`--click <css>`、`--wait <ms>`、`--waitfor <css>`、`--scroll <px>`（动作按出现顺序执行，可重复） |
| `screen` | 截整屏桌面 | `-o 输出.png` |
| `window <标题或进程名>` | 截指定窗口 | `-o 输出.png` |
| `clip` | 从剪贴板取图 | `-o 输出.png` |

> browser 模式只截视口（Chromium 命令行不支持整页截图，那是 Puppeteer/Playwright 的 API）。需要整页/交互/元素截图时用 `interact` 模式。

## 平台 × 后端矩阵

自动降级，从上到下依次尝试：

| 模式 | Windows (Git Bash) | macOS | Linux | WSL |
| --- | --- | --- | --- | --- |
| `browser`/`interact` | Chrome/Edge/Playwright 缓存 → 自举 win64 包 | Chrome.app/Playwright 缓存 → 自举 mac-x64/arm64 包 | Chromium/Playwright 缓存 → 自举 linux64 包 | 同 Linux |
| `screen` | PowerShell .NET 全屏捕获 | `screencapture` | grim → import/scrot → gnome-screenshot | PowerShell（截 Windows 桌面）→ grim → X11 |
| `window` | PowerShell（标题子串 → 进程名） | JXA 查窗口号 → `screencapture -l` | xdotool + import（仅 X11） | 同 Windows |
| `clip` | PowerShell 读剪贴板 | osascript PNGf（TIFF 走 sips 转换） | wl-paste → xclip（BMP 自动转 PNG） | Windows 剪贴板 → wl-paste → xclip |

## 环境要求

- **全平台**：bash（Windows 上即 Git Bash / MSYS2，macOS 用系统 bash 即可）
- `browser`/`interact`：任一 Chromium 系浏览器；找不到时按平台自举下载 `chrome-headless-shell` 到 `~/.cache/kit-capture/`（约 100MB，仅首次；需 curl/wget + unzip/python3/python/PowerShell 任一解压手段）。`interact` 另需 node + npm（首次自动装 puppeteer-core 到 `~/.cache/kit-capture/runtime`，不进项目依赖）
- 指定浏览器：环境变量 `KIT_SHOTFRAME_CHROMIUM` 或 `CHROME_PATH`（与 kit-shotframe 共用）
- `screen`/`window`/`clip` 在 Windows/WSL 走 `powershell.exe` interop；Linux 按显示服务器装 grim（Wayland）或 scrot/imagemagick/xdotool/xclip（X11）；macOS 全用自带工具

## 工作流

1. 判断用户要截什么：网页 → `browser`；需要先点/等/截元素 → `interact`；整个桌面 → `screen`；某个应用窗口 → `window`；「我刚截的图」→ `clip`
2. 执行对应命令，输出到用户指定的路径（默认 `~/Pictures/shotkit/`）
3. 验证输出文件存在且非空
4. 如需美化，引导用户交给 `kit-shotframe` 套框

## 示例

```bash
# 截网页，1440 宽
bash scripts/capture.sh browser https://example.com -o ~/shots/page.png --width 1440

# 剧本化截图：等欢迎页加载 → 点登录 → 只截仪表盘组件
bash scripts/capture.sh interact https://app.example.com \
  --waitfor '#welcome-page' --click '#login' --wait 800 \
  --selector '#dashboard' -o ~/shots/dash.png

# 整页截图 + 2x 像素密度
bash scripts/capture.sh interact https://example.com --fullpage --dsf 2 -o ~/shots/full.png

# 截整屏桌面
bash scripts/capture.sh screen -o ~/shots/desktop.png

# 截窗口（Windows 按标题/进程名，macOS 按进程名/窗口标题，Linux X11 按标题）
bash scripts/capture.sh window Notepad -o ~/shots/notepad.png

# 取剪贴板截图（系统截图之后运行）
bash scripts/capture.sh clip -o ~/shots/clip.png
```

## 移动端 / 商店截图小贴士

本 skill 截的是桌面环境；如果用户要的是**模拟器里的移动应用截图**（做 App Store / Play 商店图），同一组图要看起来是"一套"：

- iOS：`xcrun simctl status_bar booted override --time 9:41 --batteryLevel 100 --batteryState charged`——苹果惯例 9:41 + 满电
- Android：`adb shell am broadcast -a com.android.systemui.demo -e command enter` 进 demo mode 后统一状态栏
- 捕获后交给 `kit-shotframe`：`--device galaxy`/`iphone` + `--ratio appstore-69`/`play-phone` + `--headline` 直接出商店图

## 实现说明

- 纯 Bash + 系统工具，**零安装**；`interact` 是唯一例外（可选增强）：首次使用时往缓存目录装 `puppeteer-core`，复用同一套 Chromium 探测/自举缓存
- Windows 侧操作全部通过 `powershell.exe`（.NET `System.Drawing` / `System.Windows.Forms`），WSL 走 interop，Git Bash 直接调用
- Git Bash/MSYS 只自动转换独立路径参数，`--flag=/path` 内嵌形式不会转——传给 Windows 原生进程的路径统一过 `winify()`/`to_win_path()` 显式转换；interact 的运行时目录用 `--rt` 参数传入而非 NODE_PATH
- 输出统一为 PNG，可直接喂给 `kit-shotframe`

## 常见问题

- **screen 截出来是黑屏/只有壁纸**：macOS 需给终端「屏幕录制」权限（系统设置 → 隐私与安全性）；Wayland 下确认 `grim` 已装
- **剪贴板是 BMP 读不了**：WSLg 常见，本 skill 会自动用 ImageMagick 转换；Linux 剪贴板只有 BMP 且无 convert 时会保留 .bmp 原文件并提示
- **找不到 Chromium**：`browser`/`interact` 会自动下载 `chrome-headless-shell` 兜底（各平台都有对应构建；`kit-shotframe` 也复用这个缓存）。不想下载就装本机 Chrome/Chromium，或设置 `KIT_SHOTFRAME_CHROMIUM` / `CHROME_PATH`
- **`window` 在 Wayland 下报错**：协议限制，没有按名称截窗口的接口；改用 `screen` 截整屏后裁切
- **`interact` 报 puppeteer-core 缺失/装不上**：需要 node + npm + 网络；手动装 `npm --prefix ~/.cache/kit-capture/runtime install puppeteer-core` 再重试
- **`interact` 动作没生效**：`--click`/`--waitfor` 的选择器未命中会以非零退出码失败并写明是哪个选择器；先在浏览器 DevTools 里验证选择器，或加 `--wait` 给页面留加载时间

## Agent 兼容说明

本 skill 不绑定特定 agent。需要用户确认截图对象/模式时：有结构化选择工具的 agent 优先用工具；没有就用编号列表让用户回数字。核对截图结果时，使用当前 agent 可用的图像读取工具直接看图。
