# Skill 编写规范（SKILL-TEMPLATE）

本仓库所有 skill 遵循同一套规范，新增 skill 前先读这里。

## 目录结构

```
skills/<kebab-case 英文名>/
├── SKILL.md          # 必须
└── scripts/          # 实现脚本（可多个）
```

- 命名：小写 kebab-case（如 `wsl-capture`、`gh-pages`），语义即能力
- 每个 skill **完全自治**：不依赖兄弟目录、不依赖仓库其他文件，复制目录即可独立使用

## SKILL.md 必须包含

1. **Frontmatter**（YAML，必须）：
   ```yaml
   ---
   name: "skill-名"
   description: "一句话描述能力 + 具体触发场景（含中文口语化例句，让 AI 能准确命中）"
   ---
   ```
   - `description` 里写**何时触发**比写「这个 skill 做什么」更重要
   - 中文社区定位：description 用中文写触发语义

2. **何时使用**：3-5 条具体触发场景
3. **何时不要用**：边界（避免 AI 误用）
4. **工作流**：步骤化（探测 → 执行 → 验证）
5. **命令契约**：给出 `scripts/` 的实际命令和参数表
6. **示例**：2 个可复制命令
7. **实现说明**：依赖清单 + 与相关 skill 的边界
8. **常见问题**：2-4 条故障排查

## 实现原则

- **零依赖优先**：bash / Python 标准库 / 系统已有工具（Chromium、gh CLI）。能用标准库不用第三方包
- **确定性 > 生成式**：输出必须来自真实数据/真实截图，禁止幻觉
- **多后端降级**：能力有多个后端时按「最可靠 → 次之」排序，失败自动降级
- **可验证**：每个脚本成功/失败都要有明确输出（✅ / ✗ + 路径）
- **中文优先**：错误提示、输出信息用中文

## 脚本规范

- 每个脚本：`set -euo pipefail`（bash）。若脚本内部需要多后端降级/软失败逻辑，可用 `set -uo pipefail` 并显式处理各分支退出码（参考 `wsl-capture/scripts/capture.sh`）
- Python 脚本统一 `def main()` 入口结构
- 顶部注释写清用法
- 输出路径统一用参数传入，默认写入当前目录或 `~/Pictures`、`docs/` 等约定位置
- 退出码：`0` 成功，`1` 运行时错误，`2` 参数错误

## 提交清单

- [ ] `SKILL.md` 有 frontmatter
- [ ] 脚本可独立运行（`bash scripts/xxx.sh --help` 或 `python3 scripts/xxx.py -h` 不报错）
- [ ] README 合集索引表已加入该 skill
- [ ] 若为截图类，`docs/screenshots/` 更新示例图