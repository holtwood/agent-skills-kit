# SKILLS.md —— 我在用的 skills 清单（选型与安装索引）

本仓库**不放外部 skills 的源码**，这里只登记「我筛过、在用」的 skill 的
名称、官方安装地址、使用场景。换机器时按这份清单重装。

安装目标目录（两个都装，内容相同）：

- `~/.agents/skills/`（ZCode / DSH / Devin 系）
- `~/.claude/skills/`（Claude Code）

一键装机：`./scripts/install-skills.sh`（装本仓自研 kit-* + 打印外部源的安装命令）。

---

## 一、本仓自研（源码就在本仓库 `skills/` 下）

| Skill | 使用场景 |
|---|---|
| `kit-gzh-article-pipeline` | 公众号文章流水线：事实表 → 采访 → 写作 → 对抗审校 → 交付 |
| `kit-capture` | 截图/录屏取证 |
| `kit-gh-pages` | GitHub Pages 相关 |
| `kit-gh-stars` | GitHub Stars 相关 |
| `kit-project-hub` | 项目总览/聚合 |
| `kit-shotframe` | 截图取帧 |
| `kit-wechat-miniapp-ui-optimizer` | 微信小程序 UI 优化 |
| `kit-wechat-minigame-ui-optimizer` | 微信小游戏 UI 优化 |

安装：见 `scripts/install-skills.sh`。

## 二、外部筛选（登记上游源，不带源码）

| Skill | 使用场景 | 安装来源 |
|---|---|---|
| `baoyu-diagram` | 深色 SVG 架构图/流程图/时序图 | `github.com/JimLiu/baoyu-skills`（整个 baoyu-skills 仓库拷 `baoyu-diagram/` 子目录） |
| `baoyu-format-markdown` | md 美化（frontmatter/摘要/排版） | 同上，拷 `baoyu-format-markdown/` |
| `baoyu-markdown-to-html` | md→主题 HTML（含 Mermaid/数学/引用） | 同上，拷 `baoyu-markdown-to-html/` |
| `humanizer` | 英文去 AI 味 | `github.com/hardikpandya/stop-slop`；本机装的是 SkillHub 版 `unclecheng-reduce-ai-perception-v2@1.0.5` |
| `humanizer-zh` | 中文去 AI 味（空话/模板腔/翻译腔） | `github.com/op7418/Humanizer-zh`（git clone 后拷 SKILL 目录；本机副本带 .git 可 pull 更新） |
| `review-cy` | 工程根因诊断（修了两三次还不好时用） | GitHub，Apache-2.0，v3.0.0；**仓库地址待补**，目前可用本机副本 `~/.agents/skills/review-cy` 直拷 |
| `gzh-design` | 公众号排版引擎（md→可粘贴 HTML，多主题组件库） | `github.com/isjiamu/gzh-design-skill`（本机副本经过本地改造：装饰槽约束/图片宽度档位，见该目录 Gotchas） |
| `md2wechat` | md→公众号 HTML + 封面/配图/草稿上传（依赖同名 CLI） | 随 `md2wechat` CLI 工具发行；`md2wechat skills read md2wechat --json` 读当前二进制内嵌 SOP |
| `wechat-article-pipeline` | 定稿 md + 本地配图 → 公众号内联 HTML/长截图/完整性报告 | 来源待补（本机副本可直拷） |
| `content-headline-hacker` | 批量生成标题/封面文案 + 心理机制标注 | SkillHub：`content-headline-hacker`（ownerId 623018，v1.0.0） |
| `topic-pool` | 选题池：捕获选题信号+评分排序 | SkillHub：`erdong-topic-pool`（ownerId 611267，v1.1.0） |
| `canvas-design` | 海报/静态视觉设计（png/pdf） | Anthropic 系 skill，Apache-2.0（本机副本可直拷） |
| `liquid-glass-wxss` | 微信小程序液态玻璃 UI 改造 | 来源待补（本机副本可直拷） |

## 三、特殊来源（不走进仓流程）

| Skill | 说明 |
|---|---|
| `wechatide-skill` | 微信开发者工具 app 包内置、只读。安装=整份复制 `/Applications/wechatwebdevtools.app/Contents/Resources/app.asar.unpacked/wechatide-skill`（命令见各仓库 AGENTS.md 规则块 §1）。无网络源 |

## 四、维护约定

- 本仓改过自研 skill → 改完跑 `./scripts/install-skills.sh` 同步到两个安装目录，**安装目录不手改**（会被覆盖）。
- 外部 skill 做了本地改造（如 gzh-design 的 Gotchas）→ 在表里注明「本地改造」，别裸覆盖上游。
- 新装的外部 skill → 补进第二节表再装机；弃用的 → 从表里删掉。
- `来源待补` 的条目：下次确认上游地址时顺手填上。
