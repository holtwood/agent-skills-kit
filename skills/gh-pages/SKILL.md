---
name: "gh-pages"
description: "为 GitHub 仓库配置 GitHub Pages：自动探测仓库构建工具，生成部署 workflow 或用 gh CLI 设置源分支，最后报告 Pages 地址。触发场景：'帮我的 xxx 仓库开 GitHub Pages'、'把这个项目发布成网页'、'我的仓库怎么开 Pages'。"
---

# GH Pages · GitHub Pages 部署配置

一键为仓库开通 GitHub Pages，自动适配构建流程。

## 何时使用

- 用户想给某个仓库开 GitHub Pages / 发布成网页
- 用户问「怎么让我的 README / 文档 / 静态站上线」
- 新仓库初始化后需要 Pages 支持

## 何时不要用

- 用户要的是完整网站开发（那是编码任务，不是配置任务）
- 仓库是 fork 或没有访问权限——先确认权限

## 工作流

1. **探测仓库情况**：
   ```bash
   gh repo view <owner/repo> --json defaultBranchRef,isFork --jq '{branch: .defaultBranchRef.name, fork: .isFork}'
   gh api repos/<owner/repo>/pages --jq .status   # 200=已开 Pages，404=未开
   ```
2. **探测构建工具**（决定用「Workflow 部署」还是「分支部署」）：
   - `hugo.toml` / `hugo.yaml` / `hugo.json`，或 `config.toml` + Hugo 特征目录（`archetypes` / `content` / `layouts`）→ **hugo**（产物默认 `public`，用 Hugo 构建 workflow；hugo 配置优先于 package.json，因为 Hugo 站常带 package.json 做资源构建；`config.toml` 单独存在不视为 Hugo，避免误判 Rust/Python 等项目）
   - `package.json` 依赖含 `vitepress` → **vitepress**（产物默认 `docs/.vitepress/dist`；兼容官方脚手架默认的 `docs:build` 脚本，自动改用 `npm run docs:build`）
   - `package.json` 含 `scripts.build` → **node**（Vite / Vue / React 等通用构建）
   - `_config.yml` → **jekyll**（Pages 原生构建，源指向仓库根，走分支部署）
   - 其他（纯静态 README、index.html）→ **branch**（分支部署，默认 `/docs` 目录）
   （与 `setup-pages.sh` 的 `detect_builder` 一致）
3. **执行部署**：
   - node / vitepress / hugo → 写入 `.github/workflows/gh-pages.yml`（按框架生成对应构建步骤），`gh api` 设置 Pages 为 GitHub Actions 源
   - jekyll / 纯静态 → 用 `gh api` 把 Pages 源指向默认分支（Jekyll 用仓库根 `/`，静态站用 `/docs` 或指定目录）
4. **验证**：等 workflow 跑完（或 `gh api repos/.../pages` 查询状态），报告 `https://<owner>.github.io/<repo>/` 给用户

## 命令契约

```bash
bash <skill目录>/scripts/setup-pages.sh <owner/repo> [--mode auto|workflow|branch] [--dir docs] [--branch main] [--output dist]
```

| 参数 | 说明 | 默认 |
| --- | --- | --- |
| `--mode` | `auto` 自动探测 / `workflow` 强制 Actions / `branch` 强制分支 | `auto` |
| `--dir` | 分支部署的目录（如 `docs`；Jekyll 自动用仓库根）。注意 GitHub 分支部署源只支持 `/` 或 `/docs` | `docs` |
| `--branch` | 分支部署推送到哪个分支 | 当前默认分支 |
| `--output` | 覆盖 workflow 构建产物目录（auto 与强制 workflow 模式均按探测到的框架取默认：node=`dist`、vitepress=`docs/.vitepress/dist`、hugo=`public`） | 自动 |

## 示例

```bash
# 自动模式（推荐）
bash scripts/setup-pages.sh holtwood/my-project

# 文档站强制 Actions 部署（VitePress 会自动用 docs/.vitepress/dist）
bash scripts/setup-pages.sh holtwood/docs-site --mode workflow

# Hugo 站，自定义产物目录
bash scripts/setup-pages.sh holtwood/blog --output public
```

## 实现说明

- 依赖：[`gh` CLI](https://cli.github.com/) 已登录（`gh auth status` 检查）
- 需要 `workflow` 或 `pages` 相关权限的 token/账号
- workflow 模板按框架生成：node/vitepress 用 `actions/setup-node`（`npm ci` 失败自动回退 `npm install`），hugo 用 `peaceiris/actions-hugo`（最新版）+ `hugo --minify`，checkout 开启 `submodules: recursive`（Hugo 主题常用 submodule），push 触发分支跟随仓库默认分支，统一走 `actions/configure-pages` + `actions/deploy-pages` 标准流程
- Jekyll 不走 Actions：GitHub Pages 对 Jekyll 有原生构建，源设为仓库根即可

## 常见问题

- **403 / 权限不足**：GitHub token 需要 `repo` 写权限；fork 仓库需先取消 fork 或提升权限
- **Pages 一直 pending**：Source 设置之后需要几分钟生效；`gh api` 查询 `status` 字段
- **自定义域名**：只支持项目站特性，CNAME 域名配置需用户自己加（写在 workflow 的 `--cname` 或仓库 Settings）