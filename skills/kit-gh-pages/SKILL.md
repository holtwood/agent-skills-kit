---
name: kit-gh-pages
description: 为指定 GitHub 仓库配置 GitHub Pages，探测静态目录或 Node/VitePress/Hugo/Jekyll 构建并生成部署配置。用户明确选择 GitHub Pages 时使用；不承接完整网站开发或其他托管平台部署。
---

# 配置 GitHub Pages

`<SKILL_ROOT>` 是本文件所在目录。脚本默认会写远端 workflow 和 Pages 设置；先生成可审查的计划。

## 工作流

1. 确认目标 `owner/repo`、源分支与用户是否要求实际部署。用 `gh auth status` 检查登录；fork 本身不是禁用条件，以仓库权限为准。
2. 运行 `--dry-run` 读取远端结构与生成配置。框架判定、产物目录、依赖与现有 workflow 处理见 [部署参考](references/deployment.md)。
3. 检查计划中的构建命令、锁文件、产物目录和资源 base URL。已有部署 workflow 要先读取，不能把“已存在”视为可用配置。
4. 用户已要求配置/发布且计划符合目标时执行实际命令；仅咨询用法或缺少写入授权时交付计划。脚本不会覆盖已有 workflow，必要修改按实际需求完成。
5. 查看真实 Pages 响应、构建/部署结果和页面访问情况。配置成功只表示源已设置，部署成功必须有运行结果；地址使用 API 返回的 `html_url`，不要猜测已上线。

## 命令

```bash
bash <SKILL_ROOT>/scripts/setup-pages.sh owner/repo --dry-run
bash <SKILL_ROOT>/scripts/setup-pages.sh owner/repo --mode branch --dir docs
```

| 参数 | 用途 |
| --- | --- |
| `--mode auto|workflow|branch` | 自动判定或强制部署方式 |
| `--dir docs|/` | 分支部署目录，只支持根目录与 `/docs` |
| `--branch NAME` | 源分支，默认仓库默认分支 |
| `--output PATH` | Actions 构建产物目录，默认按框架判定 |
| `--dry-run` | 只读探测并打印计划/拟生成 workflow，不写远端 |

依赖 gh（已登录）与 Python 3。退出码 0 配置/计划成功、1 运行错误、2 参数错误。权限或构建失败按具体错误处理，不要求取消 fork。
