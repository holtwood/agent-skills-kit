---
name: kit-capture
description: 截取桌面、应用窗口、网页或剪贴板图片；支持点击、等待元素后截整页或指定元素。用于获取真实画面；截图套框使用 kit-shotframe，微信页面自动化使用开发者工具能力。
---

# 获取真实截图

交付可读取的 PNG 文件与保存路径。`<SKILL_ROOT>` 是本文件所在目录，调用脚本使用绝对路径。

## 工作流

1. 选择模式：网页视口用 `browser`；整页、元素、点击后状态用 `interact`；桌面用 `screen`；窗口用 `window`；剪贴板图片用 `clip`。
2. 使用用户指定的输出路径；未指定时脚本写入 `~/Pictures/shotkit/`。网页交互只执行任务需要的动作；点击登录入口不能代替输入凭据或已有登录会话。
3. 调用对应命令，检查退出码、输出文件，并读取图片核对目标与内容。失败时按 [平台与排错](references/platforms.md) 处理。
4. 用户还要求套框时继续使用可用的 `kit-shotframe`；截图任务本身交付 PNG 即完成。

## 命令

```bash
bash <SKILL_ROOT>/scripts/capture.sh browser https://example.com -o ./shots/page.png --width 1440
bash <SKILL_ROOT>/scripts/capture.sh interact https://example.com --waitfor '#content' --fullpage -o ./shots/full.png
bash <SKILL_ROOT>/scripts/capture.sh window '应用标题' -o ./shots/window.png
```

`screen`、`clip` 也接受 `-o`。完整交互参数见 [命令参数](references/commands.md)；`--help` 不探测或安装依赖。退出码 0 成功、1 运行失败、2 参数错误。

## 依赖与边界

- Bash；Windows 使用 Git Bash/MSYS2。网页需要 Chromium，找不到时下载到缓存；`interact` 另需 Node/npm，首次安装 puppeteer-core 到缓存。
- 无头浏览器使用独立会话，不承诺复用用户浏览器登录态。复杂认证与多步测试优先使用当前可用浏览器自动化工具。
- 微信模拟器页面截图应使用其原生截图工具；本技能的窗口截图可能包含开发者工具边框。
- 输出黑屏、截错区域或旧文件不算成功；以当前调用的退出码和图片为准。
