# 值得关注的外部 Skills（备忘录）

这里只记录**链接和用途**，不把第三方代码放进本仓库。

原因：vendored 进来就得跟着上游走 —— 每次同步都要重新校验、重新打补丁，release 资产还可能顺带删掉仓库里已有的文件（比如测试目录），维护成本远大于收益。想用的时候单独装一份就行。

## 清单

### archify

- 链接：[tt-a1i/archify](https://github.com/tt-a1i/archify)
- 用途：架构 / 流程 / 时序 / 数据流 / 状态图，输出自包含 HTML + SVG，支持主题切换与导出
- 许可：MIT
- 备注：2026-09 试用过 v2.16.0，能力确实强；但官方更新频繁，所以只记链接、不 vendor

### store-screenshots（LeeHueeng）

- 链接：[LeeHueeng/store-screenshots](https://github.com/LeeHueeng/store-screenshots)
- 用途：App Store / Google Play 商店截图生成——纯 CSS 设备框（iPhone/iPad/Galaxy/Fold/Flip）、底部出血+微倾构图、状态栏统一（9:41 满电）、品牌色提取、确认门工作流
- 备注：kit-shotframe 的 Android 机型框、商店比例、bleed/tilt/copy 层就是参考它做的；Claude Code + Codex 双兼容写法值得抄

### app-store-screenshots-skill（framara）

- 链接：[framara/app-store-screenshots-skill](https://github.com/framara/app-store-screenshots-skill)
- 用途：三层解耦（原始截图 → 文案/设计 JSON → 合成器），多语言批量出图 + App Store Connect 上传管线；auto-fit/auto-push 文案自适应；`references/` 按阶段拆参考文件
- 备注：140 帧 × 39 语言一天上架的实战派；批量商店图流水线需求直接看它

### selene · app-mockup-kit

- 链接：[tercumantanumut/selene](https://github.com/tercumantanumut/selene)
- 用途：与 kit-shotframe 同路线的确定性套壳渲染器（Chrome/Safari 浏览器框、iPhone/Pixel/iPad/MacBook），默认输出 SVG
- 备注：kit-shotframe 的 Safari 框、PDF 输出参考了它

### guizang-social-card-skill

- 链接：[op7418/guizang-social-card-skill](https://github.com/op7418/guizang-social-card-skill)
- 用途：中文社媒卡片 + 独立的 `references/screenshot-treatment.md` 截图处理规范（contain 不裁切、六维度组合舞台、WebP 纹理背景）
- 备注：kit-shotframe 的 `image:` 纹理背景思路来源

### web-screenshot（WholeNightCoding）

- 链接：[WholeNightCoding/web-screenshot](https://github.com/WholeNightCoding/web-screenshot)
- 用途：自举式网页截图——首跑自动装 puppeteer-core + chrome-headless-shell 到 `~/.cache`，剧本化捕获（元素截图/点击后再截）
- 备注：kit-capture 的自举下载与 interact 模式参考了它

<!-- 继续往下加：复制上面的小节，改链接 / 用途 / 许可 / 备注即可 -->

## 怎么装

第三方 skill 装到本机 skill 目录即可，**不要放进本仓库**：

- Codex：`~/.codex/skills/`
- Claude Code：`~/.claude/skills/`
- opencode：`~/.config/opencode/skills/`

本仓库的 `install.sh` / `install.ps1` 只管理 `skills/` 下的自研 skill，只按指定技能名称创建链接，保留其他名称的第三方 skill。

## 中文写作与多平台（2026-10-05 调研）

完整来源比较、固定提交与接入取舍见 [WRITING-SKILLS-RESEARCH.md](WRITING-SKILLS-RESEARCH.md)。推荐组合是自研写作流程 + 一个中文编辑器 + 按目标选择的渲染能力，不叠加所有同类规则。

### humanizer-zh（归藏）

- 链接：[op7418/Humanizer-zh](https://github.com/op7418/Humanizer-zh)
- 用途：中文自然编辑，保留事实、确定程度、文体与作者声音；已安装固定提交的版本
- 许可：MIT
- 备注：本流程优先采用这个审校增强；中文标点与正常连接词不列为全局禁项，不承诺检测器结果

### 已有 humanizer（unclecheng）

- 链接：SkillHub `skillhub install unclecheng-reduce-ai-perception-v2 --namespace user_ab5ae6ee`
- 用途：已有中文编辑方法库，保留本机安装，可按用户需要显式调用
- 备注：此次未找到可审查的同名公开原始仓库；不把其中标点禁令、词频与人味要求继承为通用门禁

### 宝玉的内容工具

- 链接：[JimLiu/baoyu-skills](https://github.com/JimLiu/baoyu-skills)
- 已安装：`baoyu-format-markdown`、`baoyu-markdown-to-html`、`baoyu-diagram`
- 用途：Markdown 整理、可执行 HTML 转换、技术 SVG/PNG 图解
- 许可：MIT
- 备注：脚本运行依赖按需放在技能目录；格式整理在副本进行。不要为了标题/写作批量安装其完整工具集

### gzh-design

- 链接：[isjiamu/gzh-design-skill](https://github.com/isjiamu/gzh-design-skill)
- 用途：Markdown → 公众号内联样式 HTML 的主题组件库与兼容性校验
- 许可：审查的上游版本为 AGPL-3.0-or-later
- 备注：保留已有安装和自定义主题，仍是默认公众号引擎；实际可选主题以本机索引为准

### md2wechat

- 链接：[geekjourneyx/md2wechat-skill](https://github.com/geekjourneyx/md2wechat-skill)
- 用途：公众号转换、预览和草稿，以及 CLI 准备 + 浏览器保存知乎/头条等未发布草稿
- 许可：项目自定义 Source Available（基于 BSL 1.1），具体用途以其 LICENSE 为准
- 备注：已有技能，CLI 和账号能力需实际发现；API 排版需要对应 key。不是通用的四平台直接发布 API

### 只借鉴方法

- [KKKKhazix/khazix-skills](https://github.com/KKKKhazix/khazix-skills)：材料理解、叙事节奏、自检；不迁移作者专属声线
- [zdyya/writer-skill](https://github.com/zdyya/writer-skill)：素材分层和研究/写作/核查；不引入逐阶段确认或多代理依赖
- [Zakk-LLM/Chinese-skill](https://github.com/Zakk-LLM/Chinese-skill)：中文逻辑、指代、技术术语；保留个人文章的自然语气

### content-headline-hacker / topic-pool

- 链接：SkillHub（`user_531be29f` / `user_90a020b6`）
- 用途：标题六心理触发器批量候选；选题池四维评分与状态流转
- 备注：已有轻量方法论 skill；标题数量按需，不沿用未经实测的 CTR；选题已定就跳过
