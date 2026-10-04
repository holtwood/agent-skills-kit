---
name: kit-wechat-minigame-ui-optimizer
description: 诊断或实现微信小游戏 Canvas 界面优化，检查 HUD、触摸命中、分辨率和安全区适配、精灵显示及游戏状态。用于微信小游戏绘制界面；WXML/WXSS 页面使用小程序 UI 技能。
---

# 微信小游戏界面优化

诊断请求交付有证据的问题清单；优化请求完成范围内的修改与验证。`<SKILL_ROOT>` 是本文件所在目录。

## 工作流

1. 读取项目说明、游戏规格与现有改动；从配置和 `game.json/game.js/game.ts` 定位真实游戏入口。
2. 运行只读扫描，追踪“游戏状态 → 绘制层 → 触控区域”。绘制关键词和硬编码颜色仅为候选线索。
3. 对照规格、设计稿与真实运行画面检查 HUD、坐标变换、安全区和状态反馈。具体审查点见 [审查与验证](references/review.md)。
4. 用户要求优化时完成 UI 修改；保持现有游戏循环与数据协议，计分/碰撞/关卡改动只在任务明确包含时执行。
5. 运行适用检查并验证受影响的实际游戏状态。交付改动和证据；没有模拟器/真机画面时把实际渲染标记为未验证。

## 命令

```bash
python3 <SKILL_ROOT>/scripts/diagnose.py /path/to/game
python3 <SKILL_ROOT>/scripts/diagnose.py /path/to/game --json --out ./reports/game-ui.json
```

Python 3.9+ 标准库；项目目录必填，支持 `--json`、`--out FILE`。脚本只读目标源码，报告保存提示走 stderr，JSON stdout 可直接解析。

扫描跳过依赖、构建产物、测试目录与符号链接。静态计数不能证明触控正确或帧率达标；FPS、点击命中与缩放需运行证据。退出码 0 扫描成功、1 读写错误、2 参数错误。
