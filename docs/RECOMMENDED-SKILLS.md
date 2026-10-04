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

- Claude Code：`~/.claude/skills/`
- opencode：`~/.config/opencode/skills/`

本仓库的 `install.sh` / `install.ps1` 只管理 `skills/` 下的自研 skill，不会碰到上面这两个目录里的第三方 skill。

### humanizer（unclecheng v4.1）

- 链接：SkillHub `skillhub install unclecheng-reduce-ai-perception-v2 --namespace user_ab5ae6ee`
- 用途：中文去 AI 味规则库——禁用词表、「不是A而是B」三毒判定、标点禁令、L1-L4 四层自检
- 备注：kit-gzh-article-pipeline 的写作红线与终检门禁来自它；对比过 biostart/humanizer（重名、英文向）后选定

### gzh-design

- 链接：[isjiamu/gzh-design-skill](https://github.com/isjiamu/gzh-design-skill)
- 用途：Markdown → 公众号内联样式 HTML 的主题组件库（摸鱼绿等 6 套主题）+ 合规校验脚本
- 备注：kit-gzh-article-pipeline 阶段 5 的排版引擎；校验脚本需 Python3 + Pillow

### content-headline-hacker / topic-pool

- 链接：SkillHub（`user_531be29f` / `user_90a020b6`）
- 用途：标题六心理触发器批量候选；选题池四维评分与状态流转
- 备注：轻量纯方法论 skill，分别服务流水线的标题与选题阶段
