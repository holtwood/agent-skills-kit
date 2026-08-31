---
name: "shotframe"
description: "给真实截图套上浏览器边框或 macOS 窗口框，输出精致的成品图。零依赖（只需系统 Chromium），确定性渲染（不使用任何图像生成模型）。适用于 README 配图、产品文档、应用商店截图、博客头图。"
---

# Shotframe · 截图套框

把一张「裸截图」变成有产品感的成品图：**macOS 窗口框** 或 **浏览器边框**。

## 何时使用

- 用户想把截图放进 README / 文档 / 博客，希望好看一点
- 用户提供截图文件路径，要求「加个边框/加个框」
- 用户想要应用商店（App Store / Play）风格的展示图
- 批量给一组截图统一风格

## 何时不要用

- 用户要的是「凭空生成一个 UI」——这是图像生成模型的事，本 skill 只用真实截图
- 用户只需要裁切 / 缩放 / 改格式——直接交给图像工具，别套框
- 用户明确要设备照片级的真实边框（可以用 Photoshop 类工具）

## 渲染器契约

```bash
node <skill目录>/scripts/frame.js \
  --input <截图路径> \
  --preset <browser|macos> \
  --output <输出路径.png>
```

可选参数：

| 参数 | 说明 | 默认 |
| --- | --- | --- |
| `--preset` | `browser` 浏览器边框 / `macos` macOS 窗口框 | `browser` |
| `--title` | 窗口标题（macOS 标题栏 / 浏览器标签页） | 不显示 |
| `--url` | 浏览器地址栏 URL | 不显示 |
| `--background` | 背景：`light` / `dark` | `light` |
| `--padding` | 窗口四周留白（px） | `56` |
| `--chromium` | 指定 Chromium 可执行文件路径 | 自动探测 |
| `--full-page` | 整页截取（输入为整页图时自动适配） | 自动 |

## 预设说明

- **`macos`**：圆角窗口 + 居中标题栏 + 红黄绿信号灯 + 柔和投影
- **`browser`**：标签页 + 地址栏（锁图标 + URL）+ 同款投影

## 工作流

1. **确认输入是真实截图文件**（本地路径）。如果是 URL 或「正在运行的应用」，先交给 `wsl-capture` 或浏览器工具截图，拿到文件后再调用本 skill。
2. **选 preset**：
   - Web 应用 / 仪表盘 → `browser`（除非用户点名 macOS）
   - 桌面应用 → `macos`
3. **渲染**：输出路径用描述性文件名（如 `pricing-browser.png`）。按需加 `--title` / `--url`。默认浅色背景，若截图本身是深色 UI 可换 `--background dark`。
4. **验证**：确认输出文件存在且非空（不小于输入文件的一半、且含非纯白像素），把结果路径汇报给用户。
5. 结果图可直接用于 README / 文档（配 `./docs/screenshots/xxx.png` 相对路径）。

## 示例

```bash
# macOS 窗口框
node scripts/frame.js --input ./tmp/desktop.png --preset macos \
  --title "安全同步笔记" --output ./docs/screenshots/app-macos.png

# 浏览器边框，深色背景衬深色 UI
node scripts/frame.js --input ./tmp/dark-ui.png --preset browser \
  --title "Dashboard" --url app.example.com --background dark \
  --output ./docs/screenshots/dashboard-browser.png
```

## 实现说明

- **零 npm 依赖**：渲染 = Node 标准库生成 HTML + 系统 Chromium 无头截图（`--force-device-scale-factor=2` 保证清晰度）
- Chromium 自动探测顺序：`SHOTFRAME_CHROMIUM` 环境变量 → Playwright 缓存目录 → `which chromium / google-chrome / chrome`
- 输入格式：PNG（自动读取宽高，无需额外库）
- 输出 2 倍尺寸（等价 Retina），README 里按需 `width=` 限制显示

## 常见问题

- **找不到 Chromium**：`sudo apt install chromium` 或安装 playwright 后重试；也可显式 `--chromium /path/to/chrome`
- **输出全是空白**：检查输入 PNG 是否损坏；`file input.png` 确认格式
- **想更清晰**：输出已是 2x，README 中建议 `<img width="900">` 展示