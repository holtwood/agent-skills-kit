---
name: kit-shotframe
description: 为已有真实 PNG 截图添加浏览器、macOS 或设备外框、背景和文案，输出 PNG/PDF。用于 README 配图、社交分享图和应用商店组图；不生成产品 UI，也不负责截图采集。
---

# 截图套框

使用 `scripts/frame.js` 确定性渲染。`<SKILL_ROOT>` 是本文件所在目录。

## 工作流

1. 取得真实 PNG。输入为 URL 或正在运行的应用时，先用可用截图工具获取文件。只在确认四周为多余纯色画布时使用 `--trim`。
2. 选择框：Web 用 `browser`，桌面窗口用 `macos`，移动应用或电脑展示用 `device`。设备与截图来源相符；尊重用户指定的机型和主题。
3. 选择构图。普通配图使用默认自动主题；商店组图、出血/倾斜或文案排布时读 [设计参考](references/design.md)。取值不确定时运行 `--list --json`。
4. 使用 `--json` 渲染并核对 `ok`、`exitCode`、`outputs` 尺寸及 `warnings`；读取结果图检查裁切与文字。组图先渲一张验证构图，再完成已授权的其余图片；只有用户要求审样时才等待确认。
5. 交付文件路径和实际尺寸。失败时读 [排错参考](references/troubleshooting.md)，修正输入或支持的参数后重试。

## 命令

```bash
node <SKILL_ROOT>/scripts/frame.js --input ./page.png --preset browser --output ./framed.png --json
node <SKILL_ROOT>/scripts/frame.js --input ./ios.png --preset device --device iphone \
  --ratio appstore-69 --width 1320 --headline '主要功能' --output ./store.png --json
```

完整参数与回执见 [命令契约](references/commands.md)。`--help` 查看用法，`--list` 查看合法取值。

## 依赖与完成条件

- Node ≥18 与可用 Chromium；支持 `--chromium`、`KIT_SHOTFRAME_CHROMIUM`、`CHROME_PATH`。探测会复用已有浏览器缓存，不自动下载浏览器。
- 输入仅支持 PNG；PDF 的框与文字为矢量，内嵌截图仍为位图。
- 保留现有渲染器，不为单张构图改实现。退出码 1 是运行失败，2 是参数错误，3 是尺寸验证失败；任何失败产物都不能当成完成结果。
- `--width` 只缩小不放大；`--ratio` 扩展画布；`--all` 生成九个背景变体并忽略 `--bg`。以回执尺寸和告警为准。
