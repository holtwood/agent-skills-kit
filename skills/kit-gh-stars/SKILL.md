---
name: kit-gh-stars
description: 将 GitHub Star 收藏生成带分类和搜索的单文件静态索引站，可配置每周同步。用于收藏展示或现有索引更新；自己的仓库作品集使用 kit-project-hub。
---

# GitHub 收藏索引

`<SKILL_ROOT>` 是本文件所在目录。使用真实 GitHub 数据；生成页面、配置定时同步与发布按用户请求分别执行。

## 工作流

1. 从上下文确定收藏账号；当前账号可用 `@me`。拉取到工作区 `data/starred_full.json`，该文件实际为 JSONL，名称保留兼容现有调用。
2. 使用 Python 生成 `docs/index.html`。已有中文简介映射用 `--desc-zh`；不编造翻译后的功能。
3. 本地打开或读取产物，验证记录数、分类、搜索及仓库链接。
4. 用户要求定时同步时运行 `setup-ci.sh`；配置与覆盖行为见 [自动同步](references/automation.md)。用户要求 Pages 发布时再使用可用 Pages 能力，缺少兄弟技能不阻塞本地 HTML 交付。

## 命令

```bash
bash <SKILL_ROOT>/scripts/fetch-stars.sh @me ./data/starred_full.json
python3 <SKILL_ROOT>/scripts/gen-index.py ./data/starred_full.json ./docs/index.html --title '我的收藏'
bash <SKILL_ROOT>/scripts/setup-ci.sh . --branch main
```

- `fetch-stars.sh OWNER OUT` 使用分页 API；输出 JSONL，失败保留原文件。需 gh 与 Python 3。
- `gen-index.py INPUT OUTPUT [--owner USER] [--desc-zh FILE] [--title TITLE]` 接受 JSON 数组、单条对象或 JSONL；坏 JSONL 行报告后跳过。
- `setup-ci.sh [PROJECT] [--branch NAME] [--force]` 复制本技能脚本并生成 workflow；默认保留已存在的 workflow，只有明确要求覆盖时用 `--force`。
- `--help` 可离线运行；HTML 生成只依赖 Python 标准库。

分类优先依据 topics，再用语言兜底；中文简介映射键是 `owner/repo`。未提供映射时保留原描述。交付页面路径、记录数和实际配置/发布状态。
