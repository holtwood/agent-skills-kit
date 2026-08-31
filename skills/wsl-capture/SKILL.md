---
name: "wsl-capture"
description: "从 WSL 环境截取屏幕、窗口或浏览器页面。多后端自动降级：Windows 桌面走 PowerShell interop，浏览器走 Chromium 无头，WSLg 走剪贴板。解决 WSL 开发者常见的「截不到 Windows 桌面 / 粘贴坏图」问题。"
---

# WSL Capture · WSL 环境截图

在 WSL 里运行的 AI 编程工具（opencode / Claude Code / Codex）最头疼的截图问题，这个 skill 一次解决：

- ✅ 截 **Windows 桌面**（走 `powershell.exe` interop，Linux 工具做不到）
- ✅ 截 **指定 Windows 窗口**（按标题 / 进程名）
- ✅ 截 **浏览器页面**（Chromium 无头，最稳路径）
- ✅ 从 **WSLg 剪贴板** 取图（绕过 WSLg 的 BMP 坏图问题）

## 何时使用

- 用户在 WSL 里想要「当前屏幕 / 某个窗口 / 某个网页」的截图
- 用户提到 WSL 里截图黑屏、粘贴坏图、截不到 Windows 桌面
- 截图给 AI 分析、写进文档、或准备交给 `shotframe` 套框

## 何时不要用

- 用户运行在原生 macOS / Linux 桌面（不是 WSL）——用系统自带截图或浏览器工具
- 用户只要网页截图且环境不是 WSL——直接用浏览器工具

## 命令契约

```bash
bash <skill目录>/scripts/capture.sh <mode> [参数...]
```

| 模式 | 作用 | 参数 |
| --- | --- | --- |
| `browser <url>` | 截网页 | `-o 输出.png`、`--width 1440`、`--full-page` |
| `screen` | 截当前屏幕（Windows 桌面优先） | `-o 输出.png` |
| `window <标题或进程名>` | 截指定 Windows 窗口 | `-o 输出.png` |
| `clip` | 从剪贴板取图 | `-o 输出.png` |

## 后端自动降级策略

**screen 模式**（从高到低）：

1. `powershell.exe` interop（.NET `System.Drawing` 全屏捕获）——能截 Windows 桌面
2. WSLg Wayland（`grim`）——截 WSLg 内 Linux 应用
3. X11（`scrot` / ImageMagick `import`）——截 X 输出

**browser 模式**：

1. 系统 Chromium 无头直接截图（`--headless=new --screenshot`）
2. Playwright 缓存中的 Chromium

**clip 模式**：

1. `powershell.exe` 直接读 Windows 剪贴板（绕过 WSLg 的 BMP 坏图问题）
2. `wl-paste`（WSLg，PNG 直取；BMP 用 ImageMagick 转换）

## 工作流

1. 判断用户要截什么：网页 → `browser`；整个桌面 → `screen`；某个应用窗口 → `window`；「我刚截的图」→ `clip`
2. 执行对应命令，输出到用户指定的路径（默认 `~/Pictures/shotkit/`）
3. 验证输出文件存在且非空
4. 如需美化，引导用户交给 `shotframe` 套框

## 示例

```bash
# 截网页，1440 宽
bash scripts/capture.sh browser https://example.com -o ~/shots/page.png --width 1440

# 截当前 Windows 桌面
bash scripts/capture.sh screen -o ~/shots/desktop.png

# 截标题含 "Notepad" 的窗口
bash scripts/capture.sh window Notepad -o ~/shots/notepad.png

# 取剪贴板截图（Win+Shift+S 之后运行）
bash scripts/capture.sh clip -o ~/shots/clip.png
```

## 实现说明

- 纯 Bash + 系统工具，**零安装**；浏览器截图复用 `shotframe` 的 Chromium 探测逻辑
- Windows 侧操作全部通过 `powershell.exe` interop，不依赖 WSLg 的剪贴板同步（避免 BMP `BI_BITFIELDS` 坏图）
- 输出统一为 PNG，可直接喂给 `shotframe`

## 常见问题

- **screen 截出来是黑屏**：多半在纯 Wayland 下没有走 Windows 路径；确认 `powershell.exe` 可用（`which powershell.exe`）
- **剪贴板是 BMP 读不了**：本 skill 的 `clip` 模式会自动用 WSLg 数据转换，或提示用户用 Windows 侧工具重截
- **找不到 Chromium**：`sudo apt install chromium`，或设置 `SHOTFRAME_CHROMIUM`