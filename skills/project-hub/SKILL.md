---
name: "project-hub"
description: "把 GitHub 账号下的全部仓库生成一个导航首页：卡片网格展示名称/描述/语言/Star/更新时间，可分组、可搜索，一键部署 Pages。触发场景：'做一个列出我所有仓库的导航站'、'生成我的项目主页'。参考 holtwood/repos-db 的实现模式。"
---

# Project Hub · 仓库导航站

把你的全部仓库变成一个「作品集主页」：一张卡片一个项目，访客一眼看清你做了什么。

## 何时使用

- 用户想做一个展示自己所有 GitHub 仓库的导航页
- 用户想在个人主页/简历里挂一个「我的项目」
- 已有类似站点（如 repos-db）需要重新生成/更新

## 何时不要用

- 用户只需要 README 里的仓库徽章列表——那是静态 Markdown，不用建站
- 用户想自动维护精选展示（只挑部分仓库）——那是另一个决策，先确认范围

## 工作流

1. **拉取仓库列表**：
   ```bash
   bash <skill目录>/scripts/fetch-repos.sh <owner> data/repos.json
   ```
   （内部调用 `gh repo list <owner> --json ...`，与 repos-db 的 `data/repos.json` 同源）

2. **（可选）补充中文描述**：生成 `data/desc_zh.json`（`repo 名 → 中文简介`，可人工或交给 LLM 翻译），`gen-hub.py` 会自动覆盖英文描述。

3. **生成导航页**：
   ```bash
   python3 <skill目录>/scripts/gen-hub.py data/repos.json docs/index.html --title "我的项目"
   ```
   输出自包含 HTML（内联 CSS/JS）：卡片网格（名称、描述、语言色标、Star、更新时间）+ 搜索 + 分组筛选 + 可选精选区。

4. **部署**：把 `docs/` 部署为 GitHub Pages（交给 `gh-pages` skill）。

5. **（可选）CI 每周自动审计**：写入定时 workflow（每周拉取重新生成，有变更自动提交推送，提交历史即审计留痕）：
   ```bash
   bash <skill目录>/scripts/setup-ci.sh <项目目录> [--branch main]
   ```
   它会：把 skill 脚本复制到 `<项目>/skills/project-hub/`，并写入 `.github/workflows/audit-weekly.yml`（每周一 02:00 UTC 运行，支持手动触发）。

## 命令契约

```bash
bash <skill目录>/scripts/fetch-repos.sh <owner> <repos.json> [--include-forks]
python3 <skill目录>/scripts/gen-hub.py <repos.json> <out.html> [--desc-zh desc_zh.json] [--title 标题] [--group-by language|type] [--featured a,b,c]
bash <skill目录>/scripts/setup-ci.sh <项目目录> [--branch main]
```

- `--featured a,b,c`：把指定仓库名渲染在页面顶部「⭐ 精选」高亮区（橙色描边），并自动从普通分组移除避免重复
- `--group-by type|language`：按类型（个人站点 / 项目 / Awesome 合集 / Fork / 归档）或**纯按语言**分组（Fork / 归档状态以卡片角标展示，不再单列分组）；页面上方有分组筛选按钮，可点击筛选
- `setup-ci.sh` 写入 `.github/workflows/audit-weekly.yml`（每周审计，提交历史即留痕）；默认拉取仓库 owner 的仓库，可在仓库 Variables 设置 `HUB_OWNER` 覆盖

## 示例

```bash
mkdir -p data docs
bash scripts/fetch-repos.sh holtwood data/repos.json
python3 scripts/gen-hub.py data/repos.json docs/index.html --title "holtwood 的项目" \
  --featured my-app,page-home
# 配置每周审计
bash scripts/setup-ci.sh .
# 交给 gh-pages 部署 docs/
```

## 数据与产物

- `data/repos.json`：`gh repo list` 原始结果（name、description、language、stargazersCount、updatedAt、fork、archived）
- `docs/index.html`：单文件静态站，直接进 Pages

## 实现说明

- 依赖：`gh` CLI + Python 3 标准库（零第三方包）
- 精选区通过 `--featured` 指定；分组筛选按钮 + 搜索框均为页面内 JS，单文件可离线打开
- 语言色标内置常见语言映射（JS/TS/Python/Go/Rust/Shell 等）
- `setup-ci.sh` 生成的审计 workflow 用 `GITHUB_TOKEN` 拉取仓库列表并自动提交；如启用分支保护需自行调整推送方式；仓库在组织名下或要展示他人仓库时，在仓库 Variables 设置 `HUB_OWNER`
- 与 `gh-stars` 的区别：本 skill 管「我**自己**的仓库」，`gh-stars` 管「我收藏的**别人**的仓库」

## 常见问题

- **只显示默认分支仓库**：`gh repo list` 默认只列非 fork、非 archived；如需包含 fork 加 `--include-forks`
- **描述是英文**：提供 `desc_zh.json` 可全部替换为中文；不提供则保留原文
- **更新不及时**：配置 CI 定时 workflow 后自动刷新