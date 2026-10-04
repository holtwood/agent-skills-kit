---
name: kit-wechat-miniapp-ui-optimizer
description: 诊断或实现微信小程序 WXML/WXSS 界面优化，检查主题、布局、组件状态、安全区及设计稿还原。用于原生或混合小程序页面；Canvas 小游戏使用 kit-wechat-minigame-ui-optimizer。
---

# 微信小程序界面优化

诊断请求交付有证据的问题清单；优化或实现请求直接完成范围内的代码修改与验证。`<SKILL_ROOT>` 是本文件所在目录。

## 工作流

1. 读取项目说明、设计约束及当前改动；识别 `project.config.json` 的项目类型与小程序根目录。混合项目区分 Web 和微信端；确认是游戏时使用对应游戏规则。
2. 运行只读诊断，定位全局样式、token、页面、组件、资源与已有检查命令。
3. 结合代码和真实截图评估布局与状态。需要设计稿还原或视觉验收时读 [审查与验证](references/review.md)。有 Figma 链接且连接可用时读取对应节点；无证据不声称已对比设计稿。
4. 用户要求优化时复用现有视觉系统完成修改；业务规则、接口与云数据变更只有明确在任务范围内才执行。
5. 运行适用的已有检查，取得可用的模拟器/真机画面。交付改动与验证证据；无法获取画面时明确实际渲染未验证。

## 命令

```bash
python3 <SKILL_ROOT>/scripts/diagnose.py /path/to/project
python3 <SKILL_ROOT>/scripts/diagnose.py /path/to/project --json --out ./reports/ui.json
```

Python 3.9+ 标准库；参数为项目目录、`--json`、`--out FILE`。脚本只读目标源码，`--out` 只写指定报告。JSON stdout 始终为报告，文件保存提示走 stderr。

扫描跳过依赖、构建产物、测试目录与符号链接。颜色/token 计数是静态线索，不能证明对比度、状态可用性或微信实际渲染正确。退出码 0 扫描成功、1 读写错误、2 参数错误。
