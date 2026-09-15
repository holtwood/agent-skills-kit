---
name: "shotframe"
description: "给真实截图套上浏览器边框（Chrome / Safari）、macOS 窗口框或设备框（iPhone / iPad / MacBook / Galaxy / Galaxy Flip / Galaxy Fold），可配渐变/图片背景、社媒与应用商店画布比例（OG / X / App Store / Google Play）、顶部文案层、底边出血与微倾构图、阴影档位、边缘色衬边，输出 PNG 或矢量 PDF。自动适配深色/浅色主题，零依赖（只需系统 Chromium），确定性渲染（不使用任何图像生成模型）。适用于 README 配图、产品文档、应用商店截图、博客头图、社交分享图。触发场景：'给这张截图加个手机框'、'做成 iPhone 截图效果'、'给截图加个浏览器边框'、'给截图配个渐变背景'、'做成 OG 图 / 分享图'、'做一组 App Store 商店图'。"
---

# Shotframe · 截图套框

把一张「裸截图」变成有产品感的成品图：**浏览器边框（Chrome / Safari）**、**macOS 窗口框** 或 **设备框（iPhone / iPad / MacBook / Galaxy / Flip / Fold）**。
深色 UI 自动获得深色 chrome 与深色背景，浅色 UI 自动获得浅色配色——整图对比协调，不会出现"浅色浮条贴在黑色 App 上"的违和感。

## 何时使用

- 用户想把截图放进 README / 文档 / 博客，希望好看一点
- 用户提供截图文件路径，要求「加个边框/加个框」
- 用户想要应用商店（App Store / Google Play）风格的展示图——`--ratio appstore-*`/`play-*` + `--headline` + `--bleed`/`--tilt` 就是为这个场景准备的
- 用户说「给我截图套个手机/电脑框」——移动端截图配 iPhone / iPad / Galaxy 框，桌面端配 MacBook 框
- 批量给一组截图统一风格

## 何时不要用

- 用户要的是「凭空生成一个 UI」——这是图像生成模型的事，本 skill 只用真实截图
- 用户只需要裁切 / 缩放 / 改格式——直接交给图像工具，别套框
- 用户明确要设备照片级的真实边框（可以用 Photoshop 类工具）

## 硬性契约（跨 harness 调用必须遵守）

1. **渲染必须且只能通过 `scripts/frame.js`**——禁止手写 HTML/CSS、禁止用其他截图工具"仿制"套框效果。找不到 Chromium 时如实报错，不要自行替代实现。
2. **渲染后核对退出码与尺寸**：frame.js 会校验输出尺寸（期望 = 逻辑尺寸 × 设备像素比）并自动校正重试一次；仍不符时以**退出码 3** 失败。另有**退出码 1 + `output/missing`** 表示 Chromium 退出但根本没写出文件（浏览器不可用）——两种情况都向上报告失败，不要拿构图可疑或根本不存在的产物交差。
3. **主题交给 `--theme auto`**（默认值）：深色 UI 自动得到深色 chrome。不要为适配深色模式而修改渲染器、改代码或换用手搓方案。

## 渲染器契约

```bash
node <skill目录>/scripts/frame.js \
  --input <截图路径> \
  --preset <browser|macos|device> \
  --output <输出路径.png|.pdf>
```

可选参数：

| 参数 | 说明 | 默认 |
| --- | --- | --- |
| `--preset` | `browser` 浏览器边框 / `macos` macOS 窗口框 / `device` 设备框 | `browser` |
| `--browser` | 浏览器框样式：`chrome` 标签页+地址栏 / `safari` 单行工具栏+居中地址胶囊（仅 `--preset browser` 时生效） | `chrome` |
| `--device` | 设备框机型：`iphone` / `ipad` / `macbook` / `galaxy` / `galaxy-flip` / `galaxy-fold`（仅 `--preset device` 时生效） | `iphone` |
| `--title` | 窗口标题（macOS 标题栏 / 浏览器标签页） | 不显示 |
| `--url` | 浏览器地址栏 URL | 不显示 |
| `--theme` | `auto` / `light` / `dark`——同时决定 chrome（标签页/标题栏）、外层背景与文案层的深浅配色；`auto` 按截图亮度自动选择 | `auto` |
| `--trim` | 裁掉输入四周与四角同色的**纯色空白边**（桌面背景/视口留白）后再套框；仅适用于裸截图。注意：应用自身的大片纯色空白区（如空白编辑区）也会被裁除，仅在确认四周空白是"多余画布"时使用 | 关闭 |
| `--bg` | 背景：命名渐变预设（`aurora`/`sky`/`sunset`/`ocean`/`lavender`/`forest`/`candy`/`slate`/`mono`，随 `--theme` 取深浅变体）、`solid:#0f172a`、`linear:#a8edea,#fed6e3`、`image:路径`（png/jpg/webp/gif 纹理或照片，cover 铺满）、`none`（透明） | 跟随 theme |
| `--angle` | 渐变角度（度）；对所有渐变背景生效，**包括内置主题背景** | `135` |
| `--ratio` | 画布比例：社媒（`og`/`linkedin`/`twitter`/`x`/`instagram`/`instagram-portrait`/`story`）、应用商店（`appstore-69`/`appstore-67`/`appstore-65`/`appstore-ipad`/`appstore-mac`/`play-phone`/`play-tablet`/`play-feature`/`ms-store`）或任意 `W:H` / `WxH`。**只扩画布不裁剪**，多出来的空间由背景填充 | 按内容 |
| `--width` | 目标输出宽度（px）。**只缩小不放大**；成功时宽度精确等于该值，无法做到时**明确失败**（`config/width-too-small`）或用 `warnings` 说明，绝不静默给别的尺寸。实现方式是按目标宽度直接渲染（调整设备像素比），而不是先出 2x 再整图缩小。对 `--format pdf` 无效 | 内容的 2 倍 |
| `--headline` | 画布顶部大字标题（随主题配色，字号按画布宽自适应，最多 2 行） | 不显示 |
| `--subcopy` | 标题下方一行副文案 | 不显示 |
| `--bleed` | 卡片底边出血：向下推出画布底缘裁掉——商店图"设备探出画面"的经典姿态。裸写 = 卡片高 10%，`--bleed 160` 指定 px | 关闭 |
| `--tilt` | 卡片倾斜角度（-30 ~ 30°，±2~3° 最有商店图感觉） | `0` |
| `--shadow` | 卡片投影档位：`none` / `soft`（更轻）/ `lifted`（更浮） | 跟随 theme |
| `--format` | `png` / `pdf`——pdf 走 Chromium printToPDF 输出**矢量**文件（外壳与文字矢量，内嵌截图仍是位图；`--width` 与透明背景对其无效） | `png` |
| `--inset` | 采样截图边缘最常见的颜色，在卡片内侧衬一圈同色衬边（px） | 关闭 |
| `--radius` | 卡片圆角（px，窗口/设备框） | 预设值 |
| `--transparent` | 输出透明背景 PNG（带 alpha，便于叠到任意底图上） | 关闭 |
| `--all` | 对每个背景预设各出一张；`--output` 作为基名（`out.png` → `out-aurora.png`…）。**一旦给了 `--all`，同时给的 `--bg` 会被忽略**（9 张已覆盖全部预设） | 关闭 |
| `--list` | 列出所有可用 preset / device / browser / theme / ratio / shadow / format / background 后退出（**不确定取值先跑这个**） | 关闭 |
| `--json` | 在 stdout 输出机读回执。成功与失败**顶层字段成套**：`ok` / `command` / `exitCode`（成功为 `0`）——可统一写 `if (!j.ok)` 判断，不会把成功误判成失败。成功另有 `canvas` / `outputs` / `warnings` / `format` / `copy`，失败有 `error.code` + `error.supportedFixes`；人类日志走 stderr | 关闭 |
| `--background` | （旧参数）等价于 `--bg light` / `--bg dark`，一般直接用 `--bg` | 跟随 theme |
| `--padding` | 设备/窗口四周留白（px） | `56` |
| `--chromium` | 指定 Chromium 可执行文件路径 | 自动探测 |

## 工作流

1. **确认输入是真实截图文件**（本地路径）。如果是 URL 或「正在运行的应用」，先交给 `wsl-capture` 或浏览器工具截图，拿到文件后再调用本 skill。
   - 输入应为**应用视口内容**：先裁掉桌面壁纸、原生浏览器边框等无关区域
   - 截图四周若有纯色空白边，加 `--trim` 自动裁除
2. **选 preset**：
   - Web 应用 / 仪表盘 → `browser`（点名苹果风格加 `--browser safari`；除非用户点名 macOS 窗口）
   - 桌面应用 → `macos`
   - 移动端 App 截图 → `device` + `--device iphone`；**Android 截图用 `galaxy`**（大折叠展开屏 → `galaxy-fold`，竖折 → `galaxy-flip`）。注意平台要与截图真实来源一致——把 Android 截图装进 iPhone 框是低级错误
   - 桌面端产品图想要笔记本效果 → `device` + `--device macbook`
3. **选背景与画布**（可选，但决定「是否好看」）：
   - 用户点名风格 → `--bg sunset` / `--bg solid:#0f172a` / `--bg image:纹理.png`；拿不准就 `--all` 一次出 9 张让他挑
   - 目标是社媒 / OG → `--ratio og`（或对应平台）+ `--width` 落到推荐尺寸
   - 目标是**应用商店** → `--ratio appstore-69 --width 1320`（或 `play-phone --width 1080`）+ `--headline` + `--bleed --tilt -2`——构图细节见 `references/design.md`「商店图构图」
   - 想让卡片与截图边界更自然 → `--inset 12`
   - 取值不确定时先跑 `--list`（或 `--list --json`）拿全部合法取值，不要猜
4. **渲染**：输出路径用描述性文件名（如 `pricing-browser.png`）。按需加 `--title` / `--url`。主题保持默认 `--theme auto`（深色 UI 自动适配，无需人工判断）。
5. **验证**：加 `--json` 拿机读回执——确认 `ok === true`，并核对 `outputs[].width/height` 与 `canvas` 是否符合预期。退出码非 0 时读 `error.code`，按 `references/troubleshooting.md` 排查，**不要**改用手搓方案。人类日志里的 `theme=` / `trim=` / `bg=` 可直接向用户转述。
6. 结果图可直接用于 README / 文档（配 `./docs/screenshots/xxx.png` 相对路径）。

## 批量 / 商店组图：先出样机再全量（确认门）

做一组商店图或多张同风格图时，**不要一次全渲**——先渲 1 张样机（挑最典型的截图 + 拟定文案），用当前 agent 的读图工具核对构图、主题、文案层级，给用户过目确认后再渲其余。中途发现"文案太臭标题缩成小字"、"截图带桌面边"这类问题，修的是输入与文案，不是批量重跑。

## 示例

```bash
# macOS 窗口框
node scripts/frame.js --input ./tmp/desktop.png --preset macos \
  --title "安全同步笔记" --output ./docs/screenshots/app-macos.png

# 浏览器边框，深色 UI 自动适配（--theme auto 为默认）
node scripts/frame.js --input ./tmp/dark-ui.png --preset browser \
  --title "Dashboard" --url app.example.com \
  --output ./docs/screenshots/dashboard-browser.png

# 显式深色 chrome + 裁掉四周纯色留白
node scripts/frame.js --input ./tmp/app.png --preset browser --theme dark --trim \
  --title "Dashboard" --url app.example.com \
  --output ./docs/screenshots/dashboard-dark.png

# iPhone 设备框（移动端截图）
node scripts/frame.js --input ./tmp/app-ios.png --preset device --device iphone \
  --output ./docs/screenshots/app-iphone.png

# Galaxy 设备框（Android 截图）
node scripts/frame.js --input ./tmp/app-android.png --preset device --device galaxy \
  --output ./docs/screenshots/app-galaxy.png

# Safari 风格浏览器框（单行工具栏 + 居中地址胶囊）
node scripts/frame.js --input ./tmp/dark-ui.png --preset browser --browser safari \
  --url app.example.com --output ./docs/screenshots/dashboard-safari.png

# App Store 商店图：精确 1320×2868 + 文案层 + 出血微倾
node scripts/frame.js --input ./tmp/app.png --preset device --device galaxy \
  --ratio appstore-69 --width 1320 \
  --headline "把截图变成产品图" --subcopy "零依赖 · 确定性渲染" \
  --bleed --tilt -2 --shadow lifted \
  --output ./docs/screenshots/store-01.png

# Google Play 手机槽位（1080×1920）
node scripts/frame.js --input ./tmp/app.png --preset device --device galaxy \
  --ratio play-phone --width 1080 --headline "Feature" \
  --output ./docs/screenshots/play-01.png

# 纹理/照片背景
node scripts/frame.js --input ./tmp/app.png --preset browser \
  --bg image:./assets/paper-texture.jpg \
  --output ./docs/screenshots/app-texture.png

# 矢量 PDF 输出（外壳与文字矢量，可无限放大）
node scripts/frame.js --input ./tmp/app.png --preset browser \
  --format pdf --output ./docs/screenshots/app.pdf

# 渐变背景 + 社媒比例（OG 图，1.91:1，宽 1200）
node scripts/frame.js --input ./tmp/app.png --preset browser --bg aurora \
  --ratio og --width 1200 --title "Dashboard" --url app.example.com \
  --output ./og-preview.png

# 自定义渐变 + 透明底（叠到 PPT / 任意底图）
node scripts/frame.js --input ./tmp/app.png --preset macos \
  --bg 'linear:#a8edea,#fed6e3' --angle 45 --transparent \
  --output ./card.png

# 边缘色衬边：让截图自带的浅色留白与卡片衔接
node scripts/frame.js --input ./tmp/app.png --preset browser --inset 12 \
  --output ./framed-inset.png

# 一次出全部 9 个背景预设 → out-aurora.png / out-sky.png / …
node scripts/frame.js --input ./tmp/app.png --preset macos --all --width 900 \
  --output ./out.png

# agent 用法：先发现能力，再拿机读回执
node scripts/frame.js --list --json
node scripts/frame.js --input ./tmp/app.png --preset macos --bg sky --json
```

## 示例效果

![浏览器深色主题](../../docs/screenshots/browser-dark.png)

![iPhone 设备框](../../docs/screenshots/device-iphone.png)

![MacBook 设备框](../../docs/screenshots/device-macbook.png)

## 深入参考（按需阅读）

- `references/design.md`：各 preset 的外观细节、背景/画布规则、**商店图构图手法**、渲染实现说明
- `references/troubleshooting.md`：全部 `error.code` 与退出码的对症排查

## Agent 兼容说明

本 skill 不绑定特定 agent。让用户做选择题时（背景风格、机型、构图）：有结构化选择工具的 agent（如 AskUserQuestion / 交互式菜单）优先用工具；没有就用编号列表让用户回数字。核对结果图时，使用当前 agent 可用的图像读取工具直接看图，不要只凭尺寸和日志判断。
