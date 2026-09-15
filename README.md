# agent-skills-kit

> 可安装的 Agent Skills 合集，覆盖个人开发者的「作品展示」全链路：**捕获 → 美化 → 发布 → 展示**。
> 全中文文档、中文语义触发，兼容 opencode / Claude Code / Codex 等主流 AI 编程工具。
>
> **English**: [README.en.md](./README.en.md)

## Skills

| Skill | 干什么 | 典型触发语 |
| --- | --- | --- |
| [`wsl-capture`](./skills/wsl-capture/) | WSL 截图全家桶：Windows 桌面 / 指定窗口 / 网页 / 剪贴板，多后端自动降级；无浏览器时自动下载 chrome-headless-shell；`interact` 模式支持点按钮、等元素、截指定元素或整页 | 「截个屏」「截这个网页」「截登录后的页面」「剪贴板里的图取出来」 |
| [`shotframe`](./skills/shotframe/) | 截图套壳美化：Chrome/Safari 浏览器框、macOS 窗口框、iPhone/iPad/MacBook/Galaxy/Flip/Fold 设备框；渐变/图片背景、社媒 + 应用商店精确画布、文案层、出血微倾、矢量 PDF | 「加个边框」「套个 iPhone 框」「做张 OG 图」「做一组 App Store 商店图」 |
| [`gh-pages`](./skills/gh-pages/) | GitHub Pages 一键配置，自动探测 Vite / Hugo / VitePress / Jekyll | 「给这个仓库开 Pages」 |
| [`gh-stars`](./skills/gh-stars/) | 把 GitHub 收藏生成中文分类索引站，配每周 CI 同步 | 「把我的 star 做成展示站」 |
| [`project-hub`](./skills/project-hub/) | 把名下仓库生成导航站，精选区 + 每周审计 | 「做一个列出我所有仓库的导航站」 |

## 亮点

- **商店图一条龙**：`wsl-capture` 拿到真实截图 → `shotframe` 用 `--ratio appstore-69 --width 1320` 精确落地官方槽位，`--headline`/`--subcopy` 文案层 + `--bleed`/`--tilt` 出血微倾构图，一组 App Store / Google Play 营销图直接出
- **确定性渲染**：所有输出 100% 来自真实截图与 CSS 排版，不调用任何图像生成模型——可复现、可审查、无幻觉
- **零依赖优先**：只需系统已有工具（Chromium / gh CLI / Python）；`interact` 是唯一例外（按需往缓存目录装 puppeteer-core，不进项目依赖）
- **多后端降级**：环境探测失败自动切换后端（PowerShell interop → WSLg → X11 → 自举下载），报错误码稳定可读，方便 agent 自动处理
- **Skill 自治**：每个 skill 完全自包含（`SKILL.md` + `scripts/` + `references/`），拷走即用

## 安装

### 方式一：安装脚本（推荐）

```bash
git clone https://github.com/holtwood/agent-skills-kit.git ~/agent-skills-kit
cd ~/agent-skills-kit

./install.sh                    # Linux / macOS / WSL，装全部
./install.sh shotframe gh-pages # 或按需安装
.\install.ps1                   # Windows 原生 PowerShell（junction，无需管理员）
```

### 方式二：npx skills（skills.sh）

```bash
npx skills add holtwood/agent-skills-kit            # 交互选择
npx skills add holtwood/agent-skills-kit --skill shotframe
```

### 方式三：手动复制

把 `skills/<name>/` 整个目录拷进项目的 `.opencode/skills/` 或 `.claude/skills/` 即可。

### 环境要求

- **系统**：Linux / macOS / WSL（`wsl-capture` 需 WSL + `powershell.exe`）
- **bash ≥ 4.4**（`install.sh`；macOS 装 Homebrew bash）、**PowerShell ≥ 5.1**（`install.ps1`）
- **Node ≥ 18**（`shotframe`）、**Python 3**（生成类）、**[gh CLI](https://cli.github.com/)** 已登录（GitHub 类）
- **Chromium**（截图类，自动探测；找不到时 WSL/Linux 可自动下载 chrome-headless-shell）

## 快速上手

```bash
# ── 截图 → 套框 ─────────────────────────────────────────
bash skills/wsl-capture/scripts/capture.sh browser https://example.com -o ~/shots/page.png
node skills/shotframe/scripts/frame.js --input ~/shots/page.png --preset macos --output ~/shots/page-macos.png

# ── App Store 商店图（精确 1320×2868 + 文案层 + 出血微倾）──
node skills/shotframe/scripts/frame.js --input ~/shots/app.png --preset device --device galaxy \
  --ratio appstore-69 --width 1320 \
  --headline "大字标题" --subcopy "一句副文案" --bleed --tilt -2 --shadow lifted \
  --output ~/shots/store-01.png

# ── OG / 社媒图（1.91:1，宽 1200）───────────────────────
node skills/shotframe/scripts/frame.js --input ~/shots/page.png --preset browser \
  --bg aurora --ratio og --width 1200 --output ~/shots/og.png

# ── 交互后再截（等加载 → 点登录 → 只截组件）─────────────
bash skills/wsl-capture/scripts/capture.sh interact https://app.example.com \
  --waitfor '#welcome' --click '#login' --selector '#dashboard' -o ~/shots/dash.png

# ── GitHub 系列 ─────────────────────────────────────────
bash skills/gh-stars/scripts/fetch-stars.sh holtwood data/starred_full.json
python3 skills/gh-stars/scripts/gen-index.py data/starred_full.json docs/index.html --title "我的收藏"
bash skills/project-hub/scripts/fetch-repos.sh holtwood data/repos.json
bash skills/gh-pages/scripts/setup-pages.sh holtwood/agent-skills-kit
```

## 设计原则

- **捕获与渲染分离**：先拿真实像素，再穿衣服；两者通过文件路径解耦，可独立使用
- **确定性 > 生成式**：不使用图像生成模型，输出 100% 来自真实数据
- **零依赖优先**：能只用系统工具就不引包；例外按需自举到缓存目录，不污染项目
- **失败要说人话**：非法取值立即报错并给合法取值清单（`--list` 可查全部），绝不静默回退
- **多 agent 兼容**：不绑定特定工具——有结构化选择 UI 用 UI，没有就用编号列表

## 文档

- [`docs/SKILL-TEMPLATE.md`](./docs/SKILL-TEMPLATE.md)：新增 skill 的编写规范
- [`docs/RECOMMENDED-SKILLS.md`](./docs/RECOMMENDED-SKILLS.md)：值得关注的外部 skill（只记链接，不 vendor）
- `skills/shotframe/references/`：套壳渲染的设计细节与排错手册

## 许可

[MIT](./LICENSE)
