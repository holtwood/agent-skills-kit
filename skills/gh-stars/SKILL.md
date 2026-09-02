---
name: "gh-stars"
description: "把 GitHub 收藏（Star）列表生成一个可搜索、可分类的静态索引站，支持中文描述翻译与 CI 自动同步。触发场景：'把我的收藏生成一个展示站'、'做一个 stars 页面'、'帮我整理我 star 过的项目'。参考 holtwood/stars-db 的实现模式。"
---

# GH Stars · Star 收藏索引站

把「我 Star 过的项目」变成一个有价值的展示页：分类、搜索、中文描述，一键部署到 GitHub Pages。

## 何时使用

- 用户想把自己的 GitHub Star 列表做成一个网页展示
- 用户想要「我收藏了什么」的可分享页面
- 已有类似站点（如 stars-db）需要更新/重新生成

## 何时不要用

- 用户只是想要 star 数量统计图表（推荐 star-history 类工具）
- 用户想分析收藏的编程语言分布（这是数据分析任务）

## 工作流

1. **确认目标用户**（默认 `gh api user` 的当前用户），拉取 Star 列表：
   ```bash
   bash <skill目录>/scripts/fetch-stars.sh <owner> data/starred_full.json
   ```
   （内部调用 `gh api --paginate user/starred`，与 stars-db 的 `fetch_stars.sh` 同源）

2. **生成索引站**：
   ```bash
   python3 <skill目录>/scripts/gen-index.py data/starred_full.json docs/index.html
   ```
   输出自包含 HTML（内联 CSS/JS），支持：按分类筛选、关键字搜索、中文描述优先（若 `desc_zh` 映射存在）。

3. **（可选）中文描述翻译**：如果已有 `data/desc_zh.json`（`repo 全名 → 中文简介`），传给 `gen-index.py` 自动覆盖英文描述。

4. **部署**：把 `docs/` 目录部署为 GitHub Pages（交给 `gh-pages` skill）。

5. **（可选）CI 自动同步**：写入定时 workflow（每周拉取重新生成，有变更自动提交推送）：
   ```bash
   bash <skill目录>/scripts/setup-ci.sh <项目目录> [--branch main]
   ```
   它会：把 skill 脚本复制到 `<项目>/skills/gh-stars/`，并写入 `.github/workflows/sync-stars.yml`（每周一 02:00 UTC 运行，支持手动触发）。

## 命令契约

```bash
bash <skill目录>/scripts/fetch-stars.sh <owner> <out.json>
python3 <skill目录>/scripts/gen-index.py <stars.json> <out.html> [--desc-zh desc_zh.json] [--title 标题] [--owner 用户名]
bash <skill目录>/scripts/setup-ci.sh <项目目录> [--branch main]
```

## 示例

```bash
mkdir -p data docs
bash scripts/fetch-stars.sh holtwood data/starred_full.json
python3 scripts/gen-index.py data/starred_full.json docs/index.html --title "我的收藏"
# 配置每周自动同步
bash scripts/setup-ci.sh .
# 然后交给 gh-pages 部署 docs/
```

## 数据与产物

- `data/starred_full.json`：`gh api user/starred` 原始结果（含 `starred_at`、语言、topics、描述）
- `docs/index.html`：单文件静态站，可直接进 Pages

## 实现说明

- 依赖：`gh` CLI（拉数据）+ Python 3 标准库（生成 HTML，零第三方包）
- 中文分类：按 `topics` 命中中文分类（AI/大模型、前端、后端、数据库、运维/DevOps、安全、数据科学、工具/效率、学习/文档、桌面/移动、游戏开发、Awesome 合集），`topics` 未命中再按语言映射，最后兜底「其他」
- `setup-ci.sh` 生成 `.github/workflows/sync-stars.yml`，用 `GITHUB_TOKEN` 拉取（可读公开数据）；默认拉取仓库 owner 的 Star，仓库在组织名下或要展示他人收藏时，在仓库 Variables 设置 `STARS_OWNER` 覆盖；如仓库启用了分支保护，需自行调整提交/推送方式
- 与 `project-hub` 的区别：本 skill 管「我收藏的**别人的**仓库」，`project-hub` 管「我**自己的**仓库」

## 常见问题

- **只拉到 100 个**：脚本已带 `--paginate`，确认网络正常即可全量拉取
- **中文描述为空**：`desc_zh.json` 需要人工/LLM 先行翻译；没有映射时自动回退英文描述
- **仓库太多生成慢**：千级 Star 规模秒级完成，无需担心