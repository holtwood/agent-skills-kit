# 每周同步

`setup-ci.sh [PROJECT] [--branch NAME] [--force]` 把自包含脚本复制到目标 `skills/kit-gh-stars/scripts/`，生成 `.github/workflows/sync-stars.yml`，每周一 02:00 UTC 与手动触发更新数据及页面。默认保留已有 workflow；需要覆盖时检查原配置再用 `--force`。

- 拉取账号默认仓库 owner，仓库变量 `STARS_OWNER` 可覆盖。
- 默认分支通过 origin/HEAD 或当前分支探测；worktree 的 `.git` 文件也受支持。
- workflow 在目标分支 checkout 并推送该分支；`GITHUB_TOKEN` 需要 contents 写权限，分支保护按目标项目规则处理。
- 中文简介映射 `data/desc_zh.json` 若存在会传给生成器。标题、精选和分组等定制参数在生成后按目标站点配置保留。
- 该步骤只写本地配置与脚本；启用定时执行仍需用户要求的提交/推送。提交历史记录数据变化，不能代替项目质量审计。
