# agent-skills-kit

> 可安装的 Agent Skills 合集：个人开发者的「作品展示」链路——**捕获 → 美化 → 发布 → 展示**。全中文文档，兼容 opencode / Claude Code / Codex。
>
> **English**: [README.en.md](./README.en.md)

## Skills

| Skill | 干什么 |
| --- | --- |
| [`kit-capture`](./skills/kit-capture/) | 跨平台截图（Win/macOS/Linux/WSL）：桌面 / 窗口 / 网页 / 剪贴板，多后端自动降级；`interact` 模式可点按钮、等元素、截指定元素 |
| [`kit-shotframe`](./skills/kit-shotframe/) | 截图套壳美化：浏览器 / macOS / iPhone / Galaxy 等框，社媒与应用商店精确画布，文案层，矢量 PDF |
| [`kit-gh-pages`](./skills/kit-gh-pages/) | GitHub Pages 一键配置，自动探测 Vite / Hugo / VitePress / Jekyll |
| [`kit-gh-stars`](./skills/kit-gh-stars/) | GitHub 收藏 → 中文分类索引站，配每周 CI 同步 |
| [`kit-project-hub`](./skills/kit-project-hub/) | 名下仓库 → 导航站，精选区 + 每周审计 |
| [`kit-wechat-miniapp-ui-optimizer`](./skills/kit-wechat-miniapp-ui-optimizer/) | 原生微信小程序 UI 诊断：WXML/WXSS、页面/组件、主题、安全区、资源与状态 |
| [`kit-wechat-minigame-ui-optimizer`](./skills/kit-wechat-minigame-ui-optimizer/) | 微信小游戏 Canvas UI 诊断：HUD、触摸命中区、分辨率适配、贴图、状态与帧率线索 |
| [`kit-gzh-article-pipeline`](./skills/kit-gzh-article-pipeline/) | 公众号文章全流程：选题排期 → 模拟器截图 → 去 AI 味写作 → 标题候选 → 头图渲染 → 摸鱼绿排版 → 双门禁终检 → 发布归档 |

## 安装

```bash
./install.sh                          # Linux / macOS / WSL（bash ≥ 4.4），装全部
./install.sh kit-shotframe            # 或按需安装
.\install.ps1                         # Windows 原生 PowerShell（junction）
npx skills add holtwood/agent-skills-kit   # 或用 skills.sh
```

也可手动把 `skills/<name>/` 整个拷进 `.opencode/skills/` 或 `.claude/skills/`。

依赖：`kit-capture` 在 Windows 上需 Git Bash / MSYS2 环境，桌面/窗口/剪贴板模式在 Windows 与 WSL 下走 `powershell.exe`；`kit-shotframe` 需 Node ≥ 18 + Chromium（找不到会自动下载 chrome-headless-shell）；GitHub 类需已登录的 [gh CLI](https://cli.github.com/)。

## 用法

每个 skill 的 `SKILL.md` 即完整文档。典型链路——截网页 → 套框出商店图：

```bash
bash skills/kit-capture/scripts/capture.sh browser https://example.com -o page.png
node skills/kit-shotframe/scripts/frame.js --input page.png --preset device --device galaxy \
  --ratio appstore-69 --width 1320 --headline "大字标题" --bleed -o store-01.png
```

## 原则

- **确定性**：输出 100% 来自真实截图与数据，不调用图像生成模型
- **零依赖优先**：只用系统工具；例外按需自举到缓存目录，不进项目依赖
- **Skill 自治**：每个 skill 自包含（`SKILL.md` + `scripts/`），拷走即用

## 文档

- [docs/SKILL-TEMPLATE.md](./docs/SKILL-TEMPLATE.md)：新增 skill 的编写规范
- [docs/RECOMMENDED-SKILLS.md](./docs/RECOMMENDED-SKILLS.md)：值得关注的外部 skill（只记链接）

## 许可

[MIT](./LICENSE)
