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
   - `package.json` 含 `scripts.build` → 构建型，用 GitHub Actions workflow
   - 其他（Hugo / VitePress / 纯静态 README、index.html）→ 分支部署（`/docs` 目录）
   （与 `setup-pages.sh` 的 `detect_builder` 一致）
3. **执行部署**：
   - 构建型 → 写入 `.github/workflows/gh-pages.yml`（本 skill 内置模板），`gh api` 设置 Pages 为 GitHub Actions 源
   - 纯静态 → 用 `gh api` 把 Pages 源指向 `main` 分支的 `/docs` 或独立 `gh-pages` 分支（`/docs` 更简单）
4. **验证**：等 workflow 跑完（或 `gh api repos/.../pages` 查询状态），报告 `https://<owner>.github.io/<repo>/` 给用户

## 命令契约

```bash
bash <skill目录>/scripts/setup-pages.sh <owner/repo> [--mode auto|workflow|branch] [--dir docs] [--branch main]
```

| 参数 | 说明 | 默认 |
| --- | --- | --- |
| `--mode` | `auto` 自动探测 / `workflow` 强制 Actions / `branch` 强制分支 | `auto` |
| `--dir` | 分支部署的目录（如 `docs`） | `docs` |
| `--branch` | 分支部署推送到哪个分支 | 当前默认分支 |

## 示例

```bash
# 自动模式（推荐）
bash scripts/setup-pages.sh holtwood/my-project

# 文档站强制 Actions 部署
bash scripts/setup-pages.sh holtwood/docs-site --mode workflow
```

## 实现说明

- 依赖：[`gh` CLI](https://cli.github.com/) 已登录（`gh auth status` 检查）
- 需要 `workflow` 或 `pages` 相关权限的 token/账号
- workflow 模板内置了 `actions/configure-pages` + `actions/deploy-pages` 的标准流程

## 常见问题

- **403 / 权限不足**：GitHub token 需要 `repo` 写权限；fork 仓库需先取消 fork 或提升权限
- **Pages 一直 pending**：Source 设置之后需要几分钟生效；`gh api` 查询 `status` 字段
- **自定义域名**：只支持项目站特性，CNAME 域名配置需用户自己加（写在 workflow 的 `--cname` 或仓库 Settings）