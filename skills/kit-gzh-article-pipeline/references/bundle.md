# 多平台工作区脚本

`article_bundle.py` 负责反复用到的目录初始化、清单检查和 Astro frontmatter 输出。它不代写平台稿、不判断事实真假、不解析全部 Markdown 图片语法，也不会上传或发布。

```bash
python3 <SKILL_ROOT>/scripts/article_bundle.py init /path/to/article --slug my-tool
python3 <SKILL_ROOT>/scripts/article_bundle.py init /path/to/website-post --slug my-tool --platforms astro
python3 <SKILL_ROOT>/scripts/article_bundle.py check /path/to/article --json
python3 <SKILL_ROOT>/scripts/article_bundle.py check /path/to/article --platforms astro zhihu --json
python3 <SKILL_ROOT>/scripts/article_bundle.py astro /path/to/article --json
```

初始化输出 `brief.md`、`bundle.json`、母稿、所选平台正文与 `img/`；保留已有文件，任一目标冲突就不开始初始化。待写稿有 `<!-- kit:scaffold -->` 标记，补齐正文时删除；带标记的稿件不能通过检查。已存在工作区按现有结构补清单，无需重新初始化。

## 清单约定

下面是一段教学示例，文字和数字不是作者产品事实：

```json
{
  "version": 1,
  "slug": "csv-export",
  "master": "article.md",
  "platforms": {
    "astro": {
      "draft": "article-astro-body.md",
      "title": "给工具加上 CSV 导出",
      "summary": "说明导出步骤与当前限制。",
      "frontmatter": {"title": "", "description": "", "draft": true}
    }
  },
  "facts": [
    {"id": "F1", "statement": "本示例仅演示 CSV 导出", "source": "教学材料"}
  ],
  "assets": [
    {"path": "img/export.png", "source": "教学示意图", "caption": "导出入口"}
  ],
  "must_keep": [
    {"text": "仅支持 CSV", "targets": ["master", "astro"]}
  ]
}
```

- `platforms` 的每个对象有 `draft`、`title`、`summary`（图文笔记与视频脚本还会带 `kind` 字段并检查必须的小节）；母稿和各平台稿使用独立文件。运行 `python3 <SKILL_ROOT>/scripts/article_bundle.py platforms` 可列出已登记的 16+ 个平台与 5 大分组（`wechat`、`longform`、`feed`、`notes`、`video`）；默认仅初始化主力母港 `wechat`，多平台任务通过 `--platforms <平台ID/分组名/all>` 显式指定；已有清单也可自行扩展。
- `facts` 可为空；有条目时要求唯一 `id`、主张和来源。脚本只查记录完整，不验证来源是否支持主张，仍需人工核验。
- `assets` 声明所有本次交付的素材路径与来源；脚本只检查这些文件存在且非空。编辑者另对照正文逐张查漏、解码和校验隐私，不能将漏声明误报为检查覆盖。
- `must_keep` 是作者/编辑者明确要求逐字保留的短文本，如版本、引用、重要限制；未写 `targets` 则检查母稿和所有已选平台。它不是自动事实检测器，正常改写无需强制逐字一致。
- 所有路径相对工作区，解析软链后也必须留在工作区内。需要外部素材时先按本次权限归档到工作区，再引用。

## Astro 输出

把已读取网站 schema 对应的字段写进 `astro.frontmatter`。初始化的 title/description/draft 只是待映射候选；网站实际需要 summary、publishedAt 等字段时直接替换，脚本不强加字段名。留空的 title/description 使用平台标题/摘要；其他空字段须填写或移除。

`article-astro-body.md` 只放正文，frontmatter 集中在清单；脚本保持正文和链接字节内容，使用 JSON 表示的 YAML 值正确引用冒号、多行文本、布尔值和数组。输出与 body 同目录，资源基准不变；已有输出不覆盖，继续编辑现有文件或用 `--output article-astro-v2.md` 导出新版本。

无需因知乎稿尚未完成而阻塞 Astro 导出。Astro 导出只检查母稿、Astro 稿和共同记录；不调用网站构建、不把 `draft: true` 视为所有站点都可防发布。读取网站实际行为后再决定是否写入仓库、是否构建或部署。

JSON 报告区分本地检查结果、未执行的网站验证和未尝试的发布。完整交付还需人工事实审校、实际图片检查、各格式核验；只有执行完成才记录相应状态。
