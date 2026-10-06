# 中文写作与多平台 Skills 调研

调研日期：2026-10-05。目标是个人开发者的自然表达，覆盖产品介绍、技术分享、开发复盘与观点文章，向微信公众号、Astro 网站、知乎和今日头条交付。

此次通过网页检索找到候选，再读取 10 个公开仓库的实际入口、相关参考文件、许可证与必要脚本。判断依据是事实保真、中文编辑质量、作者声音、可执行能力、依赖与平台边界，没有以 star 数量或“AI 检测率”排名。版本来自本次实际获取的 git HEAD；检索缓存和本地取到的版本有差异时，以固定提交的代码为准。

## 选择结果

| 项目 / 原始来源 | 可借鉴能力 | 处理 | 主要取舍 |
| --- | --- | --- | --- |
| [op7418/Humanizer-zh](https://github.com/op7418/Humanizer-zh) | 中文空话、指代、翻译腔、语义保真与作者声音 | 安装 `humanizer-zh`，默认审校增强 | 9 月修订强调保留限定与文体，词表是线索；适合已有文章编辑，不能替代研究 |
| [holygeek00/humanizer-zh-cn](https://github.com/holygeek00/humanizer-zh-cn) | 黑话恢复具体动作、样稿校准、中文模式示例 | 阅读并借鉴方法 | 入口同样叫 `humanizer-zh`，不再安装重名编辑器 |
| [jiji262/humanizer-chinese](https://github.com/jiji262/humanizer-chinese) | 中文模式分类、语域判断、第一人称事实边界 | 阅读并借鉴方法 | 某些改写示例需额外核对信息守恒，不能把统计规律当硬性词频要求 |
| [KKKKhazix/khazix-skills：khazix-writer](https://github.com/KKKKhazix/khazix-skills/tree/main/khazix-writer) | 吃透素材、长文推进、真实经历边界、分层审校 | 提炼到自己的写作规则 | 作者专属声线，不适合作为通用中文编辑器；不继承标点禁令、口语词配额或文化升维要求 |
| [zdyya/writer-skill](https://github.com/zdyya/writer-skill) | 来源分层、研究/写作/核查分工、平台适配 | 提炼流程 | 千行入口、多次确认、多角色执行成本较高；不整体接入其控制流程 |
| [Zakk-LLM/Chinese-skill](https://github.com/Zakk-LLM/Chinese-skill) | 指代、语法、术语、翻译和证据边界 | 提炼中文表述检查 | 全局触发、专业技术文档导向，与个人文章自然语气存在差异 |
| [JimLiu/baoyu-skills](https://github.com/JimLiu/baoyu-skills) | Markdown 整理、HTML 转换、技术图解，另有素材抓取/配图/发布 | 安装三个相关工具技能 | 实际脚本比笼统“写作 prompt”更有增益；按需使用，避免整包安装和重复编辑 |
| [isjiamu/gzh-design-skill](https://github.com/isjiamu/gzh-design-skill) | 公众号内联组件、主题、复制预览与确定性检查 | 保留已有安装，继续默认排版 | 属于排版能力，不替代中文写作；独立调用，不复制其代码进本仓库 |
| [geekjourneyx/md2wechat-skill](https://github.com/geekjourneyx/md2wechat-skill) | 公众号转换/预览/草稿；浏览器辅助知乎/头条等草稿保存 | 保留已有技能，按可用 CLI 接入 | 此机器调研时 CLI 未在 PATH；跨平台是准备加浏览器流程，不是直接发布 API |
| [wxhou/wechat-article-writer](https://github.com/wxhou/wechat-article-writer) | 公众号链路整合、教程素材组织 | 仅参考能力分解 | 固定长度、“人味”配额、默认发布流程不适合本需求；获取的根目录未见 LICENSE，不复制或安装 |

另发现 [xiaoyu-chen-ntu/chinese-writing-skill](https://github.com/xiaoyu-chen-ntu/chinese-writing-skill) 的检索结果，但本次原始仓库打开失败，git 获取返回 Repository not found。它可能已迁移或改变可见性；未把摘要当作完成审查，未安装。

## 已安装的四个补充能力

| 技能 | 用途 | 运行条件 | 本次安装位置 |
| --- | --- | --- | --- |
| `humanizer-zh` | 中文自然编辑与语义保真 | Agent 读取 Markdown 指令，无运行依赖 | `~/.codex/skills/humanizer-zh` |
| `baoyu-format-markdown` | 结构整理、中文排印 | Bun 或 `npx bun`、脚本包依赖 | `~/.codex/skills/baoyu-format-markdown` |
| `baoyu-markdown-to-html` | 可执行的 Markdown → HTML | Bun 或 `npx bun`、脚本包依赖；部分图解需浏览器 | `~/.codex/skills/baoyu-markdown-to-html` |
| `baoyu-diagram` | 技术 SVG 图解与 PNG 交付 | SVG 由 Agent 编写，PNG 脚本需 `sharp` | `~/.codex/skills/baoyu-diagram` |

安装用系统 skill-installer，固定下面的提交，不替换已有 `humanizer`。新增技能在客户端下一轮加载后可用；本轮直接读取入口并检查脚本。第三方源码与运行包均在技能目录/缓存，未进入本仓库或网站 package.json。

宝玉的格式整理默认还包含标题优化，本流程的纯排印任务只在副本执行，保留用户已有标题。HTML 转换需要核对实际图片路径和临时下载素材；技术图解用位图适配不接受独立 SVG 的平台。图解展示技术关系，不冒充产品实测截图。

实测发现：HTML 转换默认移除首个标题，frontmatter 已有文章标题而正文从 H2 开始时，首个正文小节也可能消失。接入规则因此要求按输入结构使用 `--keep-title`，并逐项核对正文小节；不把命令成功当作信息完整。

没有安装宝玉整包、多个 Humanizer、作者声线生成器和所有发布工具。`baoyu-url-to-markdown` 有用，但本次已有网页读取工具；其额外浏览器/首次配置流程暂未成为写文章的依赖。AI 配图与封面在用户确需视觉资产时再调用现有能力。

## 此次改造落点

- 保留 `kit-gzh-article-pipeline` 名称与公众号截图/封面/双 HTML 链路，扩展触发范围到中文产品、技术和观点文章。
- 将写作、平台策略、外部协作分别放到按需参考文件，入口不塞第三方完整规则。
- 先整理核心判断和事实材料，再完成 Markdown 母稿；按不同读者改标题、开篇、解释深度和结尾。
- 语言编辑核对主张、否定、范围、版本、归因和完成状态；不靠标点黑名单或虚构亲历制造自然感。
- Astro 按实际网站内容 schema、样稿、图片约定和构建命令接入。只有框架名时交付待映射稿，不能猜网站目录和字段。
- 工作区脚本创建独立稿件、检查声明的素材/事实记录/保护文字，并生成 YAML frontmatter；报告明确不覆盖事实语义、网站构建与远端编辑器。
- 本地成稿、远端未发布草稿、公开文章分开记录。账号与平台能力只有实际发现/验证后才描述。

入口：[SKILL.md](../skills/kit-gzh-article-pipeline/SKILL.md)。中文方法：[writing.md](../skills/kit-gzh-article-pipeline/references/writing.md)。平台策略：[platforms.md](../skills/kit-gzh-article-pipeline/references/platforms.md)。脚本：[article_bundle.py](../skills/kit-gzh-article-pipeline/scripts/article_bundle.py)。

## 审查版本与许可证记录

| 仓库 | 本次获取的完整提交 | 提交日期 | 仓库许可证 |
| --- | --- | --- | --- |
| op7418/Humanizer-zh | `f4518a8eab97b8bfebc66a89d34320a89bef6930` | 2026-09-23 | MIT |
| holygeek00/humanizer-zh-cn | `401e372eeb1a91045d15ec21c2d13b9d0f7842ea` | 2026-08-08 | MIT |
| jiji262/humanizer-chinese | `1d6c08e10fbfe0e1b36ac784834451c6aae0a92c` | 2026-08-01 | MIT |
| KKKKhazix/khazix-skills | `322346ded8129436b3f64707789a73e732ae24d9` | 2026-10-01 | MIT |
| zdyya/writer-skill | `dd100aaf4bb4c028bbda6b11184d232c4c0a0737` | 2026-04-22 | MIT |
| Zakk-LLM/Chinese-skill | `83983a0959dfd522a783c4783f5ccd3cbb8f7bcc` | 2026-09-13 | MIT |
| JimLiu/baoyu-skills | `1567581c26ec29f4216c6e6835415bf30343b0e3` | 2026-09-10 | MIT |
| isjiamu/gzh-design-skill | `339840b1343c86b0159d97a06a0e9eba7c09f9ba` | 2026-10-03 | AGPL-3.0-or-later |
| geekjourneyx/md2wechat-skill | `fce5fa3b4494fded0bdb942d50d17485281055d6` | 2026-09-24 | 项目自定义 Source Available，基于 BSL 1.1，具体用途以 LICENSE 为准 |
| wxhou/wechat-article-writer | `a80d36f755f3ef69312f5c482128e65ee5196bc9` | 2026-03-04 | 获取的根目录未见 LICENSE |

日期是仓库 HEAD 日期，不代表每个技能文件的独立更新日期，也不保证网页缓存和所有镜像同步。已有 gzh-design/md2wechat 的本机版本未自动覆盖；表中记录的是此次审查的上游版本。需更新时先比较本地主题与配置，保留用户定制。

## 平台能力依据

Astro 的内容集合由项目定义 schema，Markdown frontmatter 与图片处理依项目而变，参照 [官方内容集合](https://docs.astro.build/en/guides/content-collections/) 和 [Markdown 指南](https://docs.astro.build/en/guides/markdown-content/)。

md2wechat 的知乎/头条能力按上游 [跨平台工作流](https://github.com/geekjourneyx/md2wechat-skill/blob/fce5fa3b4494fded0bdb942d50d17485281055d6/skills/md2wechat/references/sync/workflow.md) 审查：准备内容，再通过正常编辑器写入和重开核验，默认只保存未发布草稿。其选择器和字符限制属于该工具的当时观察，实际操作时还要看当前平台页面，不写成官方永久规格。

公众号默认继续使用 gzh-design 及原有检查器；宝玉和 md2wechat 是可选引擎，各自采用实际检查与图片机制。不串联三个引擎，不把某一个主题校验器当其他引擎的强制合规证明。

## 补记（2026-10-06）

第二轮调研针对「AI 直接写中文公众号文章」的剩余问题，新发现与采纳：

- **[ax0x 翻译腔实战](https://blog.ax0x.ai/writing-guide-zh)**（83 篇博客重写验证）：中文翻译腔根因是训练语料多为翻译稿/论文/通稿；抽象风格指令对模型基本无效，规则须具体到「看见 X 换成 Y」或配 before/after 样例。已写入 [writing.md](../skills/kit-gzh-article-pipeline/references/writing.md) 硬经验节。
- **[muxiu2019/writing-dna-skill](https://github.com/muxiu2019/writing-dna-skill)**：风格蒸馏分语言 DNA/结构/选题/认知/视觉五层，需 20+ 篇样稿。样稿不足时用「改稿回收」——用户手改 diff 作为更准的校准信号，已写入 writing.md 与 `~/.config/agent-skills-kit/article-voice.md`。
- **[xxsang/writers-loop](https://github.com/xxsang/writers-loop)**：frame→draft→critique→revise 分阶段 + 「只从经审阅的决定学习」，与改稿回收同源。
- **排版机械层交给工具**：zhlint/autocorrect +《中文文案排版指北》作基线，阮一峰《中文技术文档的写作规范》作句法底线；`articles/.zhlintrc` 固化工作区约定（全角括号、「」直引）。已写入 [delivery.md](../skills/kit-gzh-article-pipeline/references/delivery.md)。
- **合规**：《人工智能生成合成内容标识办法》（国信办通字〔2025〕2号，2025-09-01 施行）第十条要求发布 AI 生成合成内容主动声明；公众号编辑器有对应标识选项，发布提醒已写入 delivery.md。
- **翻译腔经典根源**：余光中《怎样改进英式中文》《的的不休》是 humanizer-zh 多条模式的原始出处，writing.md 已注明对应关系。
- **爆款号公式裁剪**：场景开头、短段节奏、真实转折可用；「X不是Y，X是Z」金句公式、转折轰炸与「简说技术」定位冲突，不用（取舍记在 voice 文件）。
- **未采纳**：多 agent 审稿工作室（体量不符）、完整蒸馏流水线（样稿不足）、以「AI 检测率」为目标（与既有核验纪律冲突）。
- 本机 `humanizer-zh`（op7418 上游）补了 3 条本地模式（过渡复述句、段末信号词总结、用词去正式化）与「外部基线」节，属本地补丁，未回上游；上游更新时注意合并。
- **句长方差（burstiness）机械化**：[textpulse.ai 句长研究](https://textpulse.ai/research/ai-burstiness-sentence-length)（6 万对文本）证实 AI 改写系统性压平句长节奏（人类 CV≈0.449，AI≈0.376），收敛到均匀中长句。已落成 `scripts/prose_lint.py`：指纹词表、句首复读、句长 CV 三类检查，输出复查线索不判失败（`--strict` 才卡）。研究同时提醒单篇阈值不可靠，只作提示不作判决。
- **采访式素材采集**：参考 arcblock `interview-writer` 与 [Jim Lin 的 Byline 实践](https://www.linjiejim.com/writing/byline-ai-co-author)——缺亲历/立场时先读材料再提 2–4 个靶向问题，观点只用作者确认的回答。已写入 production.md「事实与素材」。
- **正面标杆**：阮一峰周刊第 288 期《技术写作的首要诀窍》——「单线结构」与短句白描是「简洁有趣雅致」的活样板，已写入 writing.md 结构节；周刊开源可作长期风格参照。
- **跑通实证**：prose_lint 在西瓜碰碰乐成稿上抓出「游戏物理有个经典坑」一处遗留铺垫句式（作者口味清单原已禁止），已改正文与 HTML。
- **风格理论层**：平克《风格感觉》的「古典风格」（文章是观看世界的窗，呈现而非炫耀）与「知识的诅咒」（作者默认读者懂自己懂的）给「雅致」和技术文章病根下了理论定义，已写入 writing.md 作者声音节作风格北极星；连带补充「立场也是风格资产」——四平八稳的共识比不完美的真实判断更没人味。
- **口述写作法**：参考[言之有物](https://zhouxingimprov.work/demo.html)与语音优先写作工具实践——作者口述 5–10 分钟转文字，AI 只整理不代写，口述节奏天然抗翻译腔。已写入 production.md 与 voice 文件。
- **标杆校准**：冯大辉「有价值的观点往往不是完美的」、曹政式产业大白话提供了立场感参照；voice 文件新增「参照系」节，定位阮一峰周刊为最贴近样板，明确只校准密度不模仿句式。
- **对抗性审校（本轮专题）**：核心实证依据是 Self-Correction Blind Spot——LLM 对自身输出错误漏检率约 64.5%，同样错误作为外来输入却能纠正，故对抗审校必须换身份换语境、且评审方不能带生成者的自我评价（锚定会塌缩多样性）。另证实 self-refine 会放大既有偏差，呼应「不串联多 skill 反复磨」。已写入 writing.md「对抗性审校」四攻击面（指纹/事实/读者/立场）+ 换介质技巧（say 朗读、倒读、间隔）+ 对照生成法；delivery.md 发布节加 pre-mortem；prose_lint 新增「虚胖量化」检查（无数字的量化词），10 个回归测试通过，成稿实测 0 命中。
- **一手研究补证（本轮专题：检测与评审的实证边界）**：
  - [RAID](https://aclanthology.org/2024.acl-long.674/)（ACL 2024，UPenn/CMU）：12 个检测器在 600 万条样本、11 种对抗攻击下普遍崩盘——改述、同义替换、重复惩罚即可绕过。结论：表面词频信号最脆弱，结构/事实破绽才扛得住换皮。已写入 writing.md 攻击面优先级。
  - [OpenAI 文本分类器](https://arstechnica.com/information-technology/2023/07/openai-discontinues-its-ai-writing-detector-due-to-low-rate-of-accuracy/)：2023-07 下线，挑战集真阳率 26%、误报 9%。连生成方都做不出可靠事后检测，本流水线因此把「像不像 AI」降级为线索而非门禁。
  - [SynthID-Text](https://www.nature.com/articles/s41586-024-08025-4)（Nature 2024，DeepMind）：Tournament sampling 文本水印，约 2000 万条 Gemini 回复实测不降质量，已开源。检测出路在生成端溯源（配合《标识办法》的平台侧义务），不在写作端。
  - [MT-Bench / LLM-as-judge](https://proceedings.neurips.cc/paper_files/paper/2023/hash/91f18a1287b398d378ef22505bf41832-Abstract.html)（NeurIPS 2023）：评审类模型三类实证偏差——冗长、位置、自我偏好。对照生成法已加去偏纪律：盲序、去标签、只找证据不打分。
  - [Kobak 等 excess-vocabulary](https://arxiv.org/abs/2406.07016)（Science Advances 2025，1500 万 PubMed 摘要）：数据驱动的 AI 指纹词发现法，≥13.5% 的 2024 摘要带 LLM 痕迹；AI 高频词逐年更替并反向渗入人类写作——印证词表需靠改稿回收持续更新，且只作线索。prose_lint 指纹表已补 4 个官腔词（至关重要/不容忽视/发挥重要作用/扮演重要角色）。
- **中文专项研究（本轮专题）**：
  - [JCSA 2026 台政大研究](http://csyue.nccu.edu.tw/ch/2026_ChatGPT_JCSA.pdf)：硕士生摘要 vs ChatGPT 同题中文摘要——AI 中文短句均质、词类/标点多样性低，高频「提升/提供/建议/此外/进一步/显示」与「X性」抽象名词（稳定性/适用性/依赖性）；真人区分特征是「我们」主语、虚字「之」、否定句式。简单特征分类即可达约 85% 准确率。prose_lint 据此新增「抽象名词化」「过渡词堆叠」两项密度检查（各 3 个回归测试），成稿实测仍 0 命中。
  - [NLPCC 2025 Shared Task 1 / DetectRL-ZH](https://github.com/NLP2CT/NLPCC-2025-Task1)：首个大规模中文检测基准，中文特有攻击包括回译（中→英→中）、形近字扰动、人类文本掺入 <50% 的混合攻击——混写是最难检测场景，印证人机合写路线的天然低风险。冠军方案 EnsemJudge 用多模型集成投票，再次说明单检测器不可靠。
  - [WritingBench](https://arxiv.org/pdf/2503.05244)（阿里+人大+上交，arXiv 2503.05244）：1239 条数据覆盖 6 领域 100 子场景；固定 rubric 与人类一致性 <65%，按写作意图动态生成的指标达 87%。writing.md 评审表据此改为「默认骨架+按文章类型加权」，并开源 7B critic 模型供参考。另有 [Chinese-Writing-Bench](https://github.com/zake7749/Chinese-Writing-Bench)（280 条 pairwise 评判）与 IDEA-CCNL Ziya 中文写作评测集可作后续参照。
- **简繁差异与中文社区经验（本轮专题）**：
  - 简繁转换只转字形不转词汇：台湾「網路/軟體/影片/資訊」≠ 香港「網絡/軟件/視頻」，AI 跨语料回流是典型破绽。权威对照资源：[教育部《兩岸常用詞語對照表》](https://dict.concised.moe.edu.tw/appendix.jsp?ID=54)（4800+ 组）、辅仁大学中华语文知识库、[OpenCC](https://github.com/BYVoid/OpenCC)（s2tw/s2hk 词级映射）。prose_lint 新增「地区词混用」「简繁混用」检查（含「程式化」「软体动物」语境豁免教训），voice 文件补大陆术语约定。
  - [中文维基百科《AI生成文的特徵》](https://wiki.kfd.me/wiki/Wikipedia:AI%E7%94%9F%E6%88%90%E6%96%87%E7%9A%84%E7%89%B9%E5%BE%B5)：社区维护的权威清单，补充「前景/挑战」套话章节、机械加粗、滥用表格、免责声明残留、AI 元话语泄漏等指纹；引用 2025 预印本——重度 LLM 用户识别 AI 文准确率约 90%，普通读者仅略高于随机。prose_lint 已加「AI 元话语」「前景套话」两条指纹。
  - [de-ai-prose-zh](https://github.com/YunyueLi/de-ai-prose-zh)：中文反 AI 腔社区清单（grep 可查 + prompt 模板 + skill），哲学与本地一致——只收客观套路、不决定文风品味、词表随模型换代漂移。可作 `--dict` 词表来源与对照参考。
- **结构设计层（本轮专题：从句子级到骨架级）**：
  - [STORM](https://aclanthology.org/2024.naacl-long.347/)（Stanford，NAACL 2024）：先调研→视角引导提问→出大纲→写正文的两阶段系统，比直接生成组织度高 25%、覆盖广 10%；直接让模型提问只会得到 What/When/Where 浅问题，**视角引导**（从不同立场拟问）才挖得深——采访环节据此升级为多视角提问。
  - plan-and-write 共识：[Plan Before You Write](https://proceedings.neurips.cc/paper_files/paper/2025/file/9cd4b3c9f2f1bb0208d36ca986f6f4f9-Paper-Creative_AI_Track.pdf)（NeurIPS 2025，79.4% 人认为更有趣）、[WritingPath](https://aclanthology.org/2025.naacl-industry.20.pdf)（NAACL 2025）均证明显式大纲提升组织性；[EMNLP 2025 异质递归规划](https://aclanthology.org/2025.emnlp-main.1254.pdf)补充：大纲是活脚手架，写中应可修订。
  - 金字塔原理 SCQA（情境→冲突→问题→回答）：西瓜文开头恰为实例（S 玩过→C 全是硬球→Q 能不能软→A 水果也可以是软的）；四种变体（标准/开门见山/突出忧虑/突出信心）收录备查。
  - 中文传统结构：起承转合、凤头猪肚豹尾、文似看山不喜平（详略起伏）、首尾呼应——与「均匀并列是 AI 默认骨架」互为表里，writing.md 新增「结构设计」节：文体定位→骨架选择→开头承诺→详略权重→大纲活用。
- **中文 skill 市场方案（skillhub.cn，本轮专题）**：
  - [科技公众号写作](https://skillhub.cn/skills/wechat-article-craft)（v5.18.7，仍在日更）：最完整的骨架级方案——A/B/C 骨架分型（事实骨架/论点骨架/混合）、文章原型专项纪律（多案例横评按升番排序、工具实测案例要有独立观赏价值）、「事实/论点双骨架+风格血肉」两步生成、L1/L2/L3 执行等级分流、20 个已炼化风格（量子位/晚点/Paul Graham 等）。骨架分型与原型纪律已吸收进 writing.md。
  - [财新风格写作](https://skillhub.cloud.tencent.com/skills/user_33ddb46a/weixin-article-writer)：开篇四式（事实切入/反常识冲击/设问/细节特写，须可溯源）、结尾三式（数据收束/对照收束/开放式）、数据密度纪律（每段≤3 数据点、数据必服务判断、比例感表述）、过渡句承上+启下。已吸收，并补边界——技术文的机制参数不套叙事密度规则。
  - [gracker-writing](https://github.com/Gracker/gracker-writing)（GitHub）：「矫饰性表达」（language that performs the writer）比「AI 味」定位更准；语料层精修（信息不增不减）与作者层改写分离；结构问题「失败即重写」不打词面补丁——「结构病用句子药治不好」已写入 writing.md。
  - 未采纳：L1/L2/L3 等级分流与 20 风格库对个人单作者号过重；爆文模板类（标题前 15 字抓眼球/每 300 字一图/结尾求在看）与「简说技术」定位冲突，维持原判。
- **排版规范层（本轮专题）**：
  - [微信公众平台编辑器兼容规范](https://developers.weixin.qq.com/doc/service/guide/product/plugin_spec.html)（官方）：不建议设 font-family（iOS 17+ 自定义栈与平台栈混排时字号字距不一致）、同标签同样式单子节点连续嵌套 ≤10 层（超限自动精简丢样式）、禁 !important、line-height 小于字号违规。`validate_gzh_html.py` 已新增 font-family 与嵌套链两项 WARNING 级检查；文章与 6 套主题模板的页面级字体栈已清除（等宽代码区豁免）。
  - [wechat-typesetting-cy](https://github.com/CY-CHENYUE/wechat-typesetting-cy)：「无模板」流派——每篇按 5 问现场推导设计（气质/信息形状/节奏/配色/形态语言），硬规则仅两条：微信兼容 + **内容零改动**（不自拟小标题、不造摘要、组件不携新文字）。其「内容零改动」比我们原装饰槽规则更严，已吸收为「叙述性文字优先原稿语句原位升格」。
  - [xiaowan-wechat-layout-skill](https://github.com/cyberxiaowan/xiaowan-wechat-layout-skill)：gzh-design 的真机反馈增强层——首屏完整信息单元、大章节可见性、线条色块密度、标题折行难看等检查项，已吸收进 delivery.md 手机预览清单。
  - 工具层事实标准：[doocs/md](https://github.com/doocs/md)（13k★ MD→公众号编辑器）；社区共识参数：正文 14-15px、字距 1-1.5px、行距 1.5-2、全文 ≤3 色、两端对齐。
- **内容层：观点与信息增量（本轮专题）**：
  - [Paul Graham《How to Write Usefully》](https://www.paulgraham.com/useful.html)：文章有用 = 正确×新颖×重要×简洁的乘积——「主张放到不出错的最强程度」「告诉读者不知道的（最高级：心里有但说不出的）」「以自己为重要性代理」「没从写作过程学到东西就不要发」。writing.md 新增「内容与观点」节以此为北极星，对抗审校加「增量攻击」面。
  - 分析写作方法（Writing Analytically 中文课程版）：**So What 链**（追问「那又怎样」直到触及机制/结构层；答不上来处即意义缺口）与**演进式论题**（先写最兴奋的段、归纳↔演绎回切、开头邀请不剧透、结尾论题比开头更准）。已入 writing.md。
  - 腾讯 skillhub 内容层方案：财新 skill **Step 0 选题审视**（搜前 10 条看角度分布，7/10 同角度即同质化，找异类角度）+ **T1–T4 信源分级**；科技公众号写作「用户的输入是线索不是边界」+ 半自动选题 3–5 角度；gzh-copywriter 差异化四问（输入/流程/输出/定位）。已入 writing.md 与 production.md 采访节。
  - 想法层同质化实证：[CST 研究](https://arxiv.org/html/2402.01536)（ChatGPT 用户点子更雷同且归属感更低）、[Sui Generis](https://www.pnas.org/doi/10.1073/pnas.2504966122)（PNAS，LLM 情节点跨代重复）、diversity growth rate 度量——观点与意外必须来自作者材料与采访，AI 只负责说清楚。「想法的所有权在作者」已写入 writing.md。
  - 国外 skill 参照：[content-research-writer](https://raw.githubusercontent.com/ComposioHQ/awesome-claude-skills/master/content-research-writer/SKILL.md)（协作大纲/钩子/分节反馈）、[crafting-portfolio-essays](https://github.com/lucasyhzhu-debug/crafting-portfolio-essays)（「声音不是发明的是提取的」——先问样稿与口述再写，六种 essay 原型）。

## 验证记录

本次新脚本 13 个回归用例通过，覆盖已有文章保护、脚手架未完成状态、单平台交付、保护文字丢失、事实记录来源、素材缺失、路径越界、独立稿件和 Astro 元数据/正文保留。`python3 tools/check.py` 的完整离线检查通过，仓库技能验证、官方 skill-creator 验证与 `git diff --check` 通过。此次离线入口跳过 3 个既有浏览器回归和 1 个需真实文章输入的集成用例。

外部工具用临时教学样例实际执行：Markdown 排印保留代码与重要限定；HTML 转换核对中文、代码、引用和实际可解码图片，并以 390px 浏览器截图检查排版；SVG 成功转换为 400×200 PNG。Astro 导出通过真实 YAML 解析验证字符串、多行值、布尔值和数组，正文未改变。运行环境为 `npx bun` 1.4.2、图解依赖 sharp 0.35.5；HTML 依赖使用上游 bun.lock 安装，其余运行包只在新安装技能目录。

这些测试验证确定性工具行为。实际中文稿件的事实、逻辑与声音仍需人工审校；尚未取得具体文章和网站仓库，不把样例检查报告写成用户文章已优化、网站构建通过或四平台已发布。
