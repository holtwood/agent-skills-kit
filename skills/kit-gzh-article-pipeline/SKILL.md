---
name: kit-gzh-article-pipeline
description: 为个人开发者撰写和改进中文产品介绍、技术分享、开发复盘与观点文章；以事实材料和作者声音形成 Markdown 母稿，再适配微信公众号、Astro 个人网站、知乎、今日头条等平台。支持改稿、补图和多平台交付。已有定稿仅需公众号排版时使用专门排版技能。
---

# 中文写作与多平台文章

根据已有素材进入所需阶段；不重复重做完成的工作。`<SKILL_ROOT>` 是本文件所在目录。

## 先确定交付范围

从项目、现有文章和用户要求取得主题、读者、核心判断、文章目录与目标平台。默认声音是个人开发者的自然表达，兼顾产品介绍和技术分享；用户偏好和本人样稿优先。只做用户需要的阶段，单平台任务不强制生成其他版本。

- 产品主张用源码、测试、真实运行画面或作者材料核实；外部事实查原始来源，保留日期、版本与限定。人数、次数、引语及第一人称经历不编造。
- 流程存在技能中；选题/台账与文章放用户工作区；机器故障与账号事实留本地，不写成所有用户的规则。
- 普通中文标点不是质量错误。自然表达通过明确动作、顺畅逻辑和真实判断实现，不用标点禁令、口语词配额或虚构亲历实现。

## 工作流

1. **定位与材料**：读取 [文章生产](references/production.md)。明确文章要回答的问题，整理核心主张及证据；指定主题时跳过选题。新工作区可从 [文章简报模板](assets/article-brief.md) 开始。
2. **成稿与中文审校**：读取 [中文表达与作者声音](references/writing.md)，撰写或编辑 `article.md`，先修事实和论证，再修句子与节奏。本人样稿只借鉴表达，不转移其经历和数据。可选外部能力见 [技能协作](references/integrations.md)，每一步只选一种编辑器或渲染引擎。
3. **平台适配**：用户要求多平台时读取 [平台策略](references/platforms.md)。保留母稿，分别改标题、开篇、论证详略和结尾；输出公众号、Astro、知乎、头条的独立版本。改事实先改母稿，再同步受影响版本。
4. **素材与交付**：公众号完整排版读取 [排版与交付](references/delivery.md)，保留真实截图、封面和双份 HTML；其他平台按各自格式交付。Astro 必须读取实际网站 schema、样稿与构建命令；没有网站路径时交付待映射草稿。
5. **核验与状态**：对照来源人工核验事实和作者立场，检查平台转换后的图片、代码与引用。多平台清单/本地材料用 [工作区脚本](references/bundle.md) 检查；gzh-design 双 HTML 用 `check_article.py`，其他引擎按 [交付约定](references/delivery.md) 核验。实际进入编辑器或网站构建后才报告对应验证结果。
6. **发布**：交付文件、保存远端草稿、公开发布分别记录。只在用户要求相应操作时调用实际工具；未知结果先恢复同稿核实，不重建。只有真实发布后回填链接。

## 命令

```bash
python3 <SKILL_ROOT>/scripts/article_bundle.py init /path/to/article --slug my-article
python3 <SKILL_ROOT>/scripts/article_bundle.py check /path/to/article --json
python3 <SKILL_ROOT>/scripts/article_bundle.py astro /path/to/article
bash <SKILL_ROOT>/scripts/render_cover.sh /path/to/article
python3 <SKILL_ROOT>/scripts/check_article.py /path/to/article --json
```

- 封面输入为文章目录的 `cover.html`，模板在 [assets/cover.html](assets/cover.html)。需要 Chrome/Chromium、Python 3 与 Pillow；输出 `img/cover.png` 和 `img/cover-square.png`。
- 工作区脚本只需 Python 3，负责脚手架、清单和 Astro frontmatter，不生成或评价文章质量。机器检查通过不等于事实已核验、Astro 构建通过或文章已发布。
- 终检默认检查 `article-gzh.html` 与 `article-gzh-embedded.html`；`--html`/`--embedded` 可改文件名。`--text-policy legacy` 启用历史标点限制；默认 `standard` 只查结构与完整性。`--json` 输出机器可读结果。
- `GZH_DESIGN_HOME` 指校验器文件或 skill 目录；显式路径无效、校验器警告/失败/超时均视为未通过，不回退绕过。
- 退出码 0 成功、1 检查/运行失败、2 参数错误。修改公众号脚本后运行 `python3 <SKILL_ROOT>/tests/regression.py`；多平台脚本用 `python3 <SKILL_ROOT>/tests/test_bundle.py`。

发布前仍要核对编辑器中的图片、封面裁切和 CTA。内嵌图片能否转存取决于实际编辑器行为，必须以预览验证，不能保证粘贴即成功。
