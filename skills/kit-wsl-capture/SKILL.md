---
name: "kit-wsl-capture"
description: "从 WSL 环境截取屏幕、窗口或浏览器页面。多后端自动降级：Windows 桌面走 PowerShell interop，浏览器走 Chromium 无头，WSLg 走剪贴板。另含可选的剧本化截图模式（点按钮/等元素/截指定元素）。解决 WSL 开发者常见的「截不到 Windows 桌面 / 粘贴坏图」问题。"
---

# WSL Capture · WSL 环境截图

在 WSL 里运行的 AI 编程工具（opencode / Claude Code / Codex）最头疼的截图问题，这个 skill 一次解决：

- ✅ 截 **Windows 桌面**（走 `powershell.exe` interop，Linux 工具做不到）
- ✅ 截 **指定 Windows 窗口**（按标题 / 进程名）
- ✅ 截 **浏览器页面**（Chromium 无头，最稳路径）
- ✅ **交互后再截**（点按钮、等元素出现、截某个元素/整页——可选增强模式）
- ✅ 从 **WSLg 剪贴板** 取图（绕过 WSLg 的 BMP 坏图问题）

## 何时使用

- 用户在 WSL 里想要「当前屏幕 / 某个窗口 / 某个网页」的截图
- 用户提到 WSL 里截图黑屏、粘贴坏图、截不到 Windows 桌面
- 用户要截「登录后的页面 / 点了某个按钮的状态 / 某个组件」这类需要先交互的画面
- 截图给 AI 分析、写进文档、或准备交给 `kit-shotframe` 套框

## 何时不要用

- 用户运行在原生 macOS / Linux 桌面（不是 WSL）——用系统自带截图或浏览器工具
- 用户只要网页截图且环境不是 WSL——直接用浏览器工具
- 交互剧本复杂到要录多步流程/断言状态——那是 Playwright 测试的活，本 skill 的 `interact` 只做轻量剧本

## 命令契约

```bash
bash <skill目录>/scripts/capture.sh <mode> [参数...]
```

| 模式 | 作用 | 参数 |
| --- | --- | --- |
| `browser <url>` | 截网页（打开即截，视口截图） | `-o 输出.png`、`--width 1440` |
| `interact <url>` | **剧本化截网页**（可选增强，首次用自动装 puppeteer-core 到缓存目录） | `-o 输出.png`、`--width 1440`、`--height 900`、`--dsf 1`、`--selector <css>`（只截该元素）、`--fullpage`（整页）、`--click <css>`、`--wait <ms>`、`--waitfor <css>`、`--scroll <px>`（动作按出现顺序执行，可重复） |
| `screen` | 截当前屏幕（Windows 桌面优先） | `-o 输出.png` |
| `window <标题或进程名>` | 截指定 Windows 窗口（标题**子串**匹配，不分大小写；找不到再按进程名精确/前缀匹配） | `-o 输出.png` |
| `clip` | 从剪贴板取图 | `-o 输出.png` |

> browser 模式只截视口（Chromium 命令行不支持整页截图，那是 Puppeteer/Playwright 的 API）。需要整页/交互/元素截图时用 `interact` 模式。

## 后端自动降级策略

**screen 模式**（从高到低）：

1. `powershell.exe` interop（.NET `System.Drawing` 全屏捕获）——能截 Windows 桌面
2. WSLg Wayland（`grim`）——截 WSLg 内 Linux 应用
3. X11（`scrot` / ImageMagick `import`）——截 X 输出

**browser / interact 模式**（Chromium 来源相同）：

1. 系统 Chromium 无头直接截图（`--headless=new --screenshot`）
2. Playwright 缓存中的 Chromium
3. **自举下载**：以上都没有时，自动下载 `chrome-headless-shell` 到 `~/.cache/kit-wsl-capture/`（约 100MB，仅首次；需 curl/wget + unzip/python3）

**interact 额外依赖**：首次使用 `npm install puppeteer-core@^24` 到 `~/.cache/kit-wsl-capture/runtime`（几 MB，不含浏览器本体，不进项目依赖；需要 node + npm + 网络）。

**clip 模式**：

1. `powershell.exe` 直接读 Windows 剪贴板（绕过 WSLg 的 BMP 坏图问题）
2. `wl-paste`（WSLg，PNG 直取；BMP 用 ImageMagick 转换）

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

# 截当前 Windows 桌面
bash scripts/capture.sh screen -o ~/shots/desktop.png

# 截标题含 "Notepad" 的窗口（子串匹配，也可传进程名如 notepad）
bash scripts/capture.sh window Notepad -o ~/shots/notepad.png

# 取剪贴板截图（Win+Shift+S 之后运行）
bash scripts/capture.sh clip -o ~/shots/clip.png
```

## 移动端 / 商店截图小贴士

本 skill 截的是桌面环境；如果用户要的是**模拟器里的移动应用截图**（做 App Store / Play 商店图），同一组图要看起来是"一套"：

- iOS：`xcrun simctl status_bar booted override --time 9:41 --batteryLevel 100 --batteryState charged`——苹果惯例 9:41 + 满电
- Android：`adb shell am broadcast -a com.android.systemui.demo -e command enter` 进 demo mode 后统一状态栏
- 捕获后交给 `kit-shotframe`：`--device galaxy`/`iphone` + `--ratio appstore-69`/`play-phone` + `--headline` 直接出商店图

## 实现说明

- 纯 Bash + 系统工具，**零安装**；`interact` 是唯一例外（可选增强）：首次使用时往缓存目录装 `puppeteer-core`，复用同一套 Chromium 探测/自举缓存
- Windows 侧操作全部通过 `powershell.exe` interop，不依赖 WSLg 的剪贴板同步（避免 BMP `BI_BITFIELDS` 坏图）
- 输出统一为 PNG，可直接喂给 `kit-shotframe`

## 常见问题

- **screen 截出来是黑屏**：多半在纯 Wayland 下没有走 Windows 路径；确认 `powershell.exe` 可用（`which powershell.exe`）
- **剪贴板是 BMP 读不了**：本 skill 的 `clip` 模式会自动用 WSLg 数据转换，或提示用户用 Windows 侧工具重截
- **找不到 Chromium**：browser / interact 模式会自动下载 `chrome-headless-shell` 到 `~/.cache/kit-wsl-capture/` 兜底（仅 Linux/WSL；`kit-shotframe` 也会复用这个缓存）。不想下载就 `sudo apt install chromium`，或设置 `KIT_SHOTFRAME_CHROMIUM`
- **`interact` 报 puppeteer-core 缺失/装不上**：需要 node + npm + 网络；手动装 `npm --prefix ~/.cache/kit-wsl-capture/runtime install puppeteer-core` 再重试
- **`interact` 动作没生效**：`--click`/`--waitfor` 的选择器未命中会以非零退出码失败并写明是哪个选择器；先在浏览器 DevTools 里验证选择器，或加 `--wait` 给页面留加载时间

## Agent 兼容说明

本 skill 不绑定特定 agent。需要用户确认截图对象/模式时：有结构化选择工具的 agent 优先用工具；没有就用编号列表让用户回数字。核对截图结果时，使用当前 agent 可用的图像读取工具直接看图。
