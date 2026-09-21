---
name: "kit-wechat-minigame-ui-optimizer"
description: "审查、优化并验证微信小游戏的 Canvas UI。适用于 HUD、分数/生命/暂停层、触摸命中区、分辨率适配、精灵贴图、游戏状态和帧率表现。触发场景：'诊断这个小游戏 UI'、'优化 Canvas 界面'、'检查 HUD 和按钮'、'适配不同手机尺寸'。"
---

# Kit WeChat Minigame UI Optimizer

面向微信小游戏 Canvas 界面的只读诊断与实现辅助。先识别游戏入口、绘制层级、状态机和资源，再提出有证据的改进；只有用户明确授权后才修改文件。

## 何时使用

- 检查 HUD、分数、生命、关卡、暂停、结算和引导层的信息层级。
- 检查 Canvas 坐标缩放、横竖屏、刘海/安全区和不同设备尺寸。
- 检查触摸命中区、视觉按钮与实际区域的对齐，以及按下/禁用反馈。
- 检查开始、进行中、暂停、失败、成功和重试等游戏状态。
- 检查颜色、字号、绘制顺序、精灵裁切、贴图清晰度和帧率风险。
- 根据 Figma 或微信开发者工具截图，把设计翻译为现有 Canvas 绘制 API。

## 何时不要用

- 原生 WXML/WXSS 页面、表单、tabBar、页面组件和小程序主题，使用 `kit-wechat-miniapp-ui-optimizer`。
- 只需要截桌面、网页或开发者工具窗口时，使用 `kit-capture`。
- 只需要给截图套设备外框或制作宣传图时，使用 `kit-shotframe`。
- 需要修改碰撞、合成、计分、关卡或云函数逻辑时，不把小游戏 UI skill 当成业务授权。

## 工作流

1. 读取 `AGENTS.md`、`CLAUDE.md`、README、游戏规格和当前待办；保留用户已有改动。
2. 运行 `scripts/diagnose.py`，确认 `game.json`/`game.js`、Canvas 入口、绘制 API、事件绑定、资源和现有检查命令。
3. 按“游戏状态 → 绘制层 → 触控区域”审查层级、适配、可读性、状态完整性和性能；静态颜色/坐标只作候选项。
4. 有 Figma 时，先取得目标节点设计上下文，再取得同一节点截图；没有 Figma 时依据规格和真实模拟器/真机截图。
5. 用户授权后做最小范围修改，保持游戏循环、碰撞和数据流不变。
6. 运行已有测试/检查，用微信开发者工具模拟器或真机验证至少一个实际游戏状态；缺少截图时明确标记为未验证。

## 命令契约

脚本只读扫描目标项目，不安装依赖、不修改目标项目：

```bash
python3 <skill目录>/scripts/diagnose.py <项目目录>
```

参数：

| 参数 | 作用 |
| --- | --- |
| `project-root` | 必填，微信小游戏项目根目录 |
| `--json` | 输出稳定 JSON，便于汇总多个项目 |
| `--out <文件>` | 将报告写到指定文件 |
| `-h, --help` | 查看帮助 |

示例：

```powershell
python .\scripts\diagnose.py D:\github\holtwood\melon-bump-minigame
```

```powershell
python .\scripts\diagnose.py D:\github\holtwood\melon-bump-minigame --json --out .\reports\minigame-ui.json
```

## Figma 与截图边界

纯 Canvas 代码诊断不需要 Figma 登录。需要读取私有 Figma 文件、节点上下文或设计稿截图时，需要在当前 Codex 环境完成 Figma MCP 授权。`kit-capture` 可以截桌面/网页，但不能替代微信开发者工具模拟器或真机截图。

## 实现说明

- `scripts/diagnose.py` 仅依赖 Python 标准库，支持 Windows、macOS、Linux 和 WSL。
- 脚本跳过 `.git`、`node_modules`、构建产物、覆盖率和测试目录。
- 报告的颜色、坐标和绘制 API 是静态线索，不等于视觉 bug；必须结合游戏状态和实际渲染判断。
- 不引入 Taro、uni-app、重型 UI 框架或运行时依赖。

## 常见问题

- **报告显示没有页面怎么办？** Canvas 小游戏的核心不是 WXML 页面，重点查看绘制入口、状态和触摸事件。
- **硬编码颜色一定要改成 token 吗？** 不一定；Canvas 绘制协议、品牌色和资源着色需要上下文判断。
- **没有模拟器截图能交付吗？** 可以交付静态诊断，但必须把实际渲染结论标为未验证。
- **Figma 一定要登录吗？** 纯代码扫描不需要；读取 Figma 文件和节点需要授权。
