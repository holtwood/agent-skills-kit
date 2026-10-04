# 部署判定与验证

探测读取指定分支：Hugo 配置优先；其次 VitePress 依赖；然后 `scripts.build`；Jekyll 配置；最后静态目录。

| 判定 | 方式 | 默认产物 |
| --- | --- | --- |
| Hugo | Actions，`hugo --minify` | `public` |
| VitePress | Actions，`build` 或 `docs:build` | `docs/.vitepress/dist` |
| Node | Actions，`npm run build` | `dist` |
| Jekyll | 分支，根目录 | `/` |
| 静态 | 分支 | `/docs` |

`config.toml` 需有 archetypes/content/layouts 佐证，避免误判。VitePress 默认产物须结合实际构建脚本确认。现有项目使用 pnpm/yarn 或自定义构建时，保留其工具链并调整生成的计划，不硬套 npm。

`--dry-run` 只读取仓库并打印拟生成 workflow/源设置，可作为审查产物；不会 PUT/POST。实际执行不会覆盖已有 `.github/workflows/gh-pages.yml`。

Node 模板有 npm 锁文件时使用 `npm ci` 与 npm cache；无锁文件时使用 `npm install`。不能用 `npm ci || npm install` 隐藏锁文件或安装错误。Hugo 模板启用 submodule，需检查项目 Hugo 版本与主题依赖。

分支目录只接受根与 docs；检查源分支目录实际存在。脚本输出 API 的 `html_url` 时只表示配置完成。后续用 API/Actions 实际结果确认上线，自定义域名、用户站点和仓库站点的地址以 API 为准。
