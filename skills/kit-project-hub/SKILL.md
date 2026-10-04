---
name: kit-project-hub
description: 将 GitHub 账号的仓库生成可搜索、可分组的导航主页，支持指定精选与每周同步。用于项目作品集或现有导航站更新；Star 收藏索引使用 kit-gh-stars。
---

# GitHub 项目导航

`<SKILL_ROOT>` 是本文件所在目录。从真实仓库数据生成自包含 HTML，精选范围遵循用户提供的名单。

## 工作流

1. 确定账号和展示范围。默认仅拉公开且非 fork 的仓库；需要 fork 时加 `--include-forks`。私有仓库不进入公开导航数据。
2. 生成 `docs/index.html`。中文简介映射键为仓库名；按类型或语言分组，可用 `--featured` 指定精选。
3. 检查计数、精选去重、筛选、搜索和链接；归档仓库有标记，不把静态更新时间称为质量审计结果。
4. 用户要求每周更新时读 [自动同步](references/automation.md) 并生成 workflow；要求发布时再使用 Pages 能力。本地页面交付不依赖兄弟技能。

## 命令

```bash
bash <SKILL_ROOT>/scripts/fetch-repos.sh @me ./data/repos.json
python3 <SKILL_ROOT>/scripts/gen-hub.py ./data/repos.json ./docs/index.html \
  --owner username --title '我的项目' --featured app,site
bash <SKILL_ROOT>/scripts/setup-ci.sh . --branch main
```

- 拉取命令使用分页 API，JSON 数组输出；失败保留原文件。`@me` 解析当前 gh 账号。
- 生成器接受 `--owner`、`--title`、`--desc-zh FILE`、`--group-by type|language`、`--featured a,b`。缺 URL 时用 `--owner` 补完整地址。
- CI 参数为 `[PROJECT] [--branch NAME] [--force]`；默认保留已有 workflow。仅用户明确要求覆盖时使用 `--force`。
- gh 与 Python 3 用于拉取；HTML 生成只依赖标准库；`--help` 可离线运行。

交付页面路径、仓库数、精选名单和实际配置/发布状态。
