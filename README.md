# agent-skills-kit

> 可安装的 Agent Skills 合集：个人开发者的「作品展示」链路——**捕获 → 美化 → 发布 → 展示**。全中文文档，兼容 opencode / Claude Code / Codex。
>
> **English**: [README.en.md](./README.en.md)

## Skills

| Skill | 干什么 |
| --- | --- |
| [`kit-capture`](./skills/kit-capture/) | 跨平台截图（Win/macOS/Linux/WSL）：桌面 / 窗口 / 网页 / 剪贴板，多后端自动降级；`interact` 模式可点按钮、等元素、截指定元素 |
| [`kit-shotframe`](./skills/kit-shotframe/) | 截图套壳美化：浏览器 / macOS / iPhone / Galaxy 等框，社媒与应用商店画布比例，文案层，矢量 PDF |
| [`kit-gh-pages`](./skills/kit-gh-pages/) | GitHub Pages 一键配置，自动探测 Vite / Hugo / VitePress / Jekyll |
| [`kit-gh-stars`](./skills/kit-gh-stars/) | GitHub 收藏 → 中文分类索引站，配每周 CI 同步 |
| [`kit-project-hub`](./skills/kit-project-hub/) | 名下仓库 → 导航站，精选区 + 每周数据同步 |
| [`kit-wechat-miniapp-ui-optimizer`](./skills/kit-wechat-miniapp-ui-optimizer/) | 原生微信小程序 UI 诊断：WXML/WXSS、页面/组件、主题、安全区、资源与状态 |
| [`kit-wechat-minigame-ui-optimizer`](./skills/kit-wechat-minigame-ui-optimizer/) | 微信小游戏 Canvas UI 诊断：HUD、触摸命中区、分辨率适配、贴图、状态与帧率线索 |
| [`kit-gzh-article-pipeline`](./skills/kit-gzh-article-pipeline/) | 中文产品/技术文章：事实与作者声音、中文审校、公众号 / Astro / 知乎 / 头条适配、素材与交付检查 |

## 安装

```bash
./install.sh                          # Linux / macOS / WSL，自带 Bash 3.2 即可
./install.sh --agent codex kit-shotframe  # 只安装到 Codex
./install.sh --dry-run                # 预演，不写目标目录
.\install.ps1 -Agent codex           # Windows PowerShell（junction）
npx skills add holtwood/agent-skills-kit   # 或用 skills.sh
```

安装器默认链接到 Codex、Claude Code 和 opencode，仓库更新后链接立即使用新版本。`--list` 查看可安装技能；已有普通目录会保留并报告冲突，退出码为 1。

| 客户端 | 默认全局安装位置 | 覆盖变量 |
| --- | --- | --- |
| Codex | `${CODEX_HOME:-~/.codex}/skills/` | `CODEX_SKILLS_DIR` |
| Claude Code | `~/.claude/skills/` | `CLAUDE_SKILLS_DIR` |
| opencode | `~/.config/opencode/skills/` | `OPENCODE_SKILLS_DIR` |

也可把任意 `skills/<name>/` 完整复制到客户端技能目录。安装本仓库不触碰其他名称的技能。

依赖：`kit-capture` 在 Windows 上需 Git Bash / MSYS2 环境，桌面/窗口/剪贴板模式在 Windows 与 WSL 下走 `powershell.exe`；`kit-shotframe` 需 Node ≥ 18 + Chromium（复用已有浏览器及缓存，不自动下载）；GitHub 类需已登录的 [gh CLI](https://cli.github.com/)。

## 用法

每个 skill 的 `SKILL.md` 是精简入口，详细参数和条件流程在相邻 `references/` 中按需读取。典型链路——截网页 → 套框出商店图：

```bash
bash skills/kit-capture/scripts/capture.sh interact https://example.com --width 390 --height 844 --dsf 2 -o page.png
node skills/kit-shotframe/scripts/frame.js --input page.png --preset device --device iphone \
  --ratio appstore-69 --width 1320 --headline "大字标题" --bleed -o store-01.png
```

## 原则

中文写作可以直接说：「用 kit-gzh-article-pipeline 把这些产品材料写成文章，保持个人开发者的自然表达，分别交付公众号、Astro、知乎和头条版本。」只需要改稿或一个平台时，技能只进入对应阶段。外部能力与选择依据见 [写作技能调研](./docs/WRITING-SKILLS-RESEARCH.md)。

- **真实证据**：截图和仓库数据来自真实输入，文章功能与经历有依据；套框使用确定性渲染
- **零依赖优先**：只用系统工具；例外按需自举到缓存目录，不进项目依赖
- **独立分发**：技能脚本不引用兄弟目录；编排技能按需使用外部能力，并说明缺失时能交付什么
- **最小入口**：触发描述明确，参考按需读取，用户已授权的工作连续完成

## 检查与维护

```bash
python3 tools/validate_skills.py       # 标准库：元数据、引用、脚本路径和 README 索引
python3 tools/check.py                 # 离线检查全部脚本与回归；公众号测试需 Pillow
python3 tools/check.py --render        # 增加真实 Chromium 渲染，需本机浏览器
```

本地检查与 CI 共用入口。浏览器测试只访问临时目录中的本地 fixture；GitHub 操作使用离线替身。历史文章标点限制需显式传 `--text-policy legacy`，默认允许正常中文标点。

## 文档

- [docs/SKILL-TEMPLATE.md](./docs/SKILL-TEMPLATE.md)：新增 skill 的编写规范
- [docs/RECOMMENDED-SKILLS.md](./docs/RECOMMENDED-SKILLS.md)：值得关注的外部 skill（只记链接）
- [docs/WRITING-SKILLS-RESEARCH.md](./docs/WRITING-SKILLS-RESEARCH.md)：中文写作与多平台技能调研、审查版本及接入取舍

## 许可

[MIT](./LICENSE)
