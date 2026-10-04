---
name: kit-gzh-article-pipeline
description: 为自有微信小程序或小游戏编写公众号产品介绍，交付底稿、真实截图、封面和可粘贴 HTML；支持已有文章补图与改稿。普通文章排版使用专门排版技能，独立选题管理使用选题技能。
---

# 产品公众号文章

根据已有素材进入所需阶段；不重复重做完成的工作。`<SKILL_ROOT>` 是本文件所在目录。

## 先确定交付范围

从当前项目与文章工作区取得产品、文章目录和编辑偏好。完整文章交付底稿、素材、封面、双份 HTML 与检查结果；局部修改只更新受影响产物。工作区位置或产品确实不明时询问，同时可检查已有材料。

- 产品主张用源码、测试、真实运行画面或作者材料核实；人数、次数与第一人称经历不编造。
- 流程存在技能中；选题/台账与文章放用户工作区；机器故障与账号事实留本地，不写成所有用户的规则。
- 普通中文标点不是质量错误。文风遵循用户偏好，只有既有项目要求时启用历史标点策略。

## 工作流

1. **事实与底稿**：核实主要功能和版本，形成关键主张到依据的对应记录。用户已指定产品就跳过选题。完整采集与写作流程见 [文章生产](references/production.md)。
2. **素材与成稿**：取得真实截图、撰写或更新底稿和标题。按需使用已安装的写作/标题技能；它们缺失时仍可交付有事实依据的底稿。
3. **排版与封面**：仅进入这一阶段时读取 [排版、依赖与交付](references/delivery.md)。封面用自带模板和脚本；公众号 HTML 使用可用的 gzh-design 组件与校验器。该必需能力缺失时交付已完成素材并明确 HTML 未完成。
4. **验证**：运行 `check_article.py`，检查图片真实解码、双产物一致、兼容性。再检查桌面/手机渲染和事实/语言。局部更新重验受影响产物；标题单独候选或选题任务不要求不存在的 HTML。
5. **交付或发布**：成稿与已发布是不同状态。只有用户要求实际发布且当前账号/工具支持时进入发布；根据真实结果回填台账，不预先填发布链接。

## 命令

```bash
bash <SKILL_ROOT>/scripts/render_cover.sh /path/to/article
python3 <SKILL_ROOT>/scripts/check_article.py /path/to/article --json
```

- 封面输入为文章目录的 `cover.html`，模板在 [assets/cover.html](assets/cover.html)。需要 Chrome/Chromium、Python 3 与 Pillow；输出 `img/cover.png` 和 `img/cover-square.png`。
- 终检默认检查 `article-gzh.html` 与 `article-gzh-embedded.html`；`--html`/`--embedded` 可改文件名。`--text-policy legacy` 启用历史标点限制；默认 `standard` 只查结构与完整性。`--json` 输出机器可读结果。
- `GZH_DESIGN_HOME` 指校验器文件或 skill 目录；显式路径无效、校验器警告/失败/超时均视为未通过，不回退绕过。
- 退出码 0 成功、1 检查/运行失败、2 参数错误。修改脚本后运行 `python3 <SKILL_ROOT>/tests/regression.py`。

发布前仍要核对编辑器中的图片、封面裁切和 CTA。内嵌图片能否转存取决于实际编辑器行为，必须以预览验证，不能保证粘贴即成功。
