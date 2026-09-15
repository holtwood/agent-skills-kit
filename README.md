# agent-skills-kit · 自用 Agent Skills 集合

> 可安装的 Agent Skill 集合：**捕获 → 美化 → 发布 → 展示**，覆盖个人开发者的完整「作品展示」链路。
> 兼容 opencode / Claude Code 等主流 AI 编程工具。
>
> **English**: [README.en.md](./README.en.md)

全中文文档、中文语义触发、开箱即用的 Agent Skills 合集。

## Skill 一览

| Skill | 能力 | 场景 |
| --- | --- | --- |
| [`wsl-capture`](./skills/wsl-capture/) | WSL 环境截图 | 「帮我在 WSL 截个屏 / 截网页 / 截窗口」 |
| [`shotframe`](./skills/shotframe/) | 截图套框（浏览器 / macOS / 设备框；渐变背景、社媒比例 OG·X·Instagram、边缘色衬边、透明底，自动适配深浅主题） | 「给截图加个边框」「套个 iPhone / MacBook 框」「做成 OG 分享图」 |
| [`gh-pages`](./skills/gh-pages/) | GitHub Pages 配置（多框架探测） | 「帮我给 xxx 仓库开 GitHub Pages」 |
| [`gh-stars`](./skills/gh-stars/) | Star 收藏索引站（中文分类 + CI 同步） | 「把我的收藏生成一个展示站」 |
| [`project-hub`](./skills/project-hub/) | 仓库导航站（精选区 + 每周审计） | 「做一个列出我所有仓库的导航站」 |

## 设计理念

- **捕获与渲染分离**：截图类 skill 先拿真实像素，再穿衣服，两者通过文件路径解耦，可独立使用
- **多后端降级**：每个能力都有多套后端（PowerShell interop → WSLg → X11），环境探测失败自动降级
- **确定性 > 生成式**：不调用任何图像生成模型，输出 100% 来自真实数据
- **零依赖优先**：脚本只依赖系统已有工具（Chromium / gh CLI / Python 标准库）
- **Skill 自治**：每个 skill 完全自包含（`SKILL.md` + `scripts/`），可独立复制到任意项目使用

## 安装

**macOS / Linux / WSL：**

```bash
git clone https://github.com/holtwood/agent-skills-kit.git ~/agent-skills-kit
cd ~/agent-skills-kit

# 安装全部 skill 到本机（opencode + Claude Code 双支持）
./install.sh

# 或按需安装指定 skill
./install.sh shotframe gh-pages
```

**Windows（原生 PowerShell）：**

```powershell
git clone https://github.com/holtwood/agent-skills-kit.git $HOME\agent-skills-kit
cd $HOME\agent-skills-kit

# 安装全部 skill（使用目录联接 junction，无需管理员权限 / 开发者模式）
.\install.ps1

# 或按需安装
.\install.ps1 shotframe gh-pages
```

> 想给某个具体项目用？直接把对应 `skills/<name>/` 目录复制进项目的 `.opencode/skills/` 或 `.claude/skills/` 即可。

### 环境要求

- **系统**：Linux / macOS / WSL（`wsl-capture` 需 WSL + `powershell.exe`）；Windows 原生用 `install.ps1` 安装
- **bash ≥ 4.4**（`install.sh` 使用 `mapfile -d`；macOS 请用 Homebrew 的 bash）；Windows 走 `install.ps1`（PowerShell ≥ 5.1）
- **Node ≥ 18**（`shotframe`）；bash 类脚本在 Windows 上可于 Git Bash / WSL 中运行
- **依赖按需**：截图类需要系统 Chromium（Linux / macOS / Windows 自动探测）；GitHub 类需要 [gh CLI](https://cli.github.com/) 已登录；生成类需要 Python 3

## 快速上手

```bash
# 截图 → 套框 一条龙（窗口框 / 设备框）
bash skills/wsl-capture/scripts/capture.sh browser https://example.com -o ~/shots/page.png
node skills/shotframe/scripts/frame.js --input ~/shots/page.png --preset macos --output ~/shots/page-macos.png
node skills/shotframe/scripts/frame.js --input ~/shots/app.png --preset device --device iphone --output ~/shots/app-iphone.png

# 渐变背景 + 社媒比例（OG 图 1.91:1，宽 1200）；--list 可列出全部预设
node skills/shotframe/scripts/frame.js --input ~/shots/page.png --preset browser \
  --bg aurora --ratio og --width 1200 --output ~/shots/og.png

# Star 收藏站（拉取 → 生成索引 → 配置每周 CI 同步）
bash skills/gh-stars/scripts/fetch-stars.sh holtwood data/starred_full.json
python3 skills/gh-stars/scripts/gen-index.py data/starred_full.json docs/index.html --title "我的收藏"
bash skills/gh-stars/scripts/setup-ci.sh .

# 仓库导航站（拉取 → 生成导航页 → 配置每周审计）
bash skills/project-hub/scripts/fetch-repos.sh holtwood data/repos.json
python3 skills/project-hub/scripts/gen-hub.py data/repos.json docs/index.html --title "我的项目" --featured my-app
bash skills/project-hub/scripts/setup-ci.sh .

# 或部署为 GitHub Pages（自动探测 Vite / Hugo / VitePress / Jekyll）
bash skills/gh-pages/scripts/setup-pages.sh holtwood/agent-skills-kit
```

## 值得关注的外部 Skills

第三方 skill 只在这里记录链接，**不 vendor 进本仓库**——省掉每次上游更新都要同步、打补丁的麻烦。清单见 [`docs/RECOMMENDED-SKILLS.md`](./docs/RECOMMENDED-SKILLS.md)。

安装第三方 skill 请直接装进 `~/.claude/skills/` 或 `~/.config/opencode/skills/`；本仓库的 `install.sh` / `install.ps1` 只管理 `skills/` 下的自研 skill。

## 新增 Skill

想往合集里加新 skill？先读 [`docs/SKILL-TEMPLATE.md`](./docs/SKILL-TEMPLATE.md) 的编写规范，保持风格统一。

## 许可

[MIT](./LICENSE)