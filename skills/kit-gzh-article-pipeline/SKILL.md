---
name: "kit-gzh-article-pipeline"
description: "微信公众号文章全流程流水线（面向个人开发者的产品介绍/推广文）：选题排期 → 模拟器截图采集 → 去 AI 味写作 → 标题候选 → 头图渲染 → 组件库排版 → 双门禁终检 → 发布归档。触发场景：'给某个小程序写篇公众号文'、'发公众号'、'写一篇介绍文/推广文'、'起几个标题'、'排版成公众号格式'、'这期公众号写什么'。编排多个 skill 与外部工具，产出固定目录结构的成稿与可粘贴 HTML。"
---

# Kit GZH Article Pipeline · 公众号文章全流程

把「给自家产品写一篇图文并茂、没有 AI 味的公众号文章」固化成八阶段流水线。设计原则只有两条：

- **确定性 > 生成式**：产品语义必须来自仓库 spec，截图必须来自真实模拟器，校验必须跑脚本
- **数据与流程分离**：流程在本文件，数据（选题池/台账/成稿）在工作区，现场坑在 memory

## 何时使用

- 「给 XX 小程序写一篇公众号介绍文」（从零到可粘贴的完整成稿）
- 「公众号排版」「转成公众号 HTML」（只跑阶段 5-6）
- 「起几个公众号标题」（只跑阶段 3）
- 「这期公众号写什么 / 该发哪篇了」（只跑阶段 0，读选题池）
- 「公众号文章发布后记一下数据」（只跑阶段 8，写台账）

## 何时不要用

- 只想要 Markdown 转普通网页 / 博客 HTML —— 用排版工具或直接写，不需要这条流水线
- 想自动发布到公众号后台 —— 个人订阅号没有草稿箱 API（认证账号才有）；开发者工具 wechatide/MCP 无公众号能力。本 skill 的发布形态是「内嵌版 HTML 粘贴」，自动化边界见常见问题
- 文案里需要产品 spec 里没有的功能 —— 先补 spec 再写，本 skill 禁止脑补产品能力
- 视频号 / 抖音口播脚本 —— 超出范围

## 工作流（八阶段）

### 阶段 0 · 选题与排期

读 `articles/选题池.md`（topic-pool 格式，四维评分：热度 15 + 个人优势 15 + 信息差 10 + 时效性 10）。
产品素材源头是各作品仓库的 `README.md` 与 `docs/design/product.md`，**语义必须对照 spec 核对**。
红线：个人主体口径 —— 文中不出现「AI」表述；升级版才有的能力不写进当前版文案。

### 阶段 1 · 素材采集（截图）

走微信开发者工具 CLI/MCP（须先过 `check_wechatide_status` 门禁；本机 clientName 实测 `Devin`）：

1. `open_project_window` → `simulator_refresh` → **等 6 秒**再操作（新开窗立即自动化必报 `page node not found`）
2. 页面导航用 `automation_evaluate` 执行 `wx.navigateTo({url:...})` / `wx.navigateBack()`；
   **不要用 `callMethod openRecent`**（内部等云端，会把整条命令挂死且退出码是 0，别信退出码）
3. 预置表单：`automation_page_action --action setData --patch '{...}'` → `callMethod submit` 可真创建数据；
   **用完必须删**（mock `showModal` 返回 `{"confirm":true}` + 触发删除方法，走完 restore）
4. 每篇 4-6 张：首页（多模式则各一张）→ 使用/参与页 → 结果页；存 `<工作区>/<slug>/img/`，按叙事命名 `01-xx.png`

### 阶段 2 · 写作（humanizer 规则落笔即遵守）

结构模板：**场景痛点开头（具体到人数/条数）→ 功能叙事 2-4 段（每段配图）→ 产品原则（真实并列项）→ CTA → 带自嘲的结尾**。
写作红线：无破折号 ——、无冒号 ：（含章节标题与图注）、无「不是A而是B」、结尾不升华；1200-1800 字；第一人称。

### 阶段 3 · 标题

用 content-headline-hacker 六触发器出 8-13 个候选（好奇心缺口/损失厌恶/社会认同/权威背书/稀缺/反常识），
张力按 hook-level 2（punchy）起步，证据不足降 1（克制）。事实边界：`刚刚/全网/第一/榜首/变天`
没有文章证据就不用；公众号 ≤30 字。**最终标题由用户确认**。封面大字与标题视角错开：标题卖「为什么点开」，
封面卖「里面讲什么」。

### 阶段 4 · 配图

头图用 `scripts/render_cover.sh`（基于 `cover.html` 模板，改文案换截图后一键渲染 900×383 头图 + 500×500 次图）。
正文截图宽 62%、max-width 320px 居中 + 12px 灰图注（图注同样无冒号无破折号）。
可选增强：跨平台网页截图用 `kit-capture`，截图套壳美化用 `kit-shotframe`（与模拟器截图互补，非依赖）。

### 阶段 5 · 排版（gzh-design 摸鱼绿）

组件一律从 gzh-design 主题库取、不手写；产品文配方：cover-breaking（有图版）→ toc-scroll →
章节标题 PART 01..N + LAST → 段落 + 图片 → pill-list（原则清单）→ green-info → footer-cta。
产出两份：`article-gzh.html`（本地路径，存档）与 `article-gzh-embedded.html`（base64 内嵌，**粘贴用这份**）。

### 阶段 6 · 双门禁终检（都过才算完）

1. humanizer L1：`grep -n "——\|："` 于 HTML 正文 **零命中** + 禁用词表 + 通读（活人感）
2. gzh-design 校验脚本 ERROR/警告清零 + Chrome headless 720px 渲染截图人工过目

### 阶段 7 · 发布

浏览器打开 embedded 版 → 全选复制 → 粘贴进公众号编辑器（图片自动转存素材库）→ 传头图 → 手机预览 → 群发。
多平台图片口径：公众号/百家号/知乎编辑器自动转存粘贴图；**百家号等平台外链图会被剥离**；
自有网站用对象存储图床（目录设公有读）。

### 阶段 8 · 归档与复盘

发布后在 `articles/发布台账.md` 记一行（日期/标题/平台/链接/48h 数据）；选题池状态流转
（🟢 待写 → 🟡 排队 → ✅ 已发布）。新坑回写本机 memory，反复验证的升级回本文件。

## 命令契约

### scripts/render_cover.sh

```bash
bash scripts/render_cover.sh <含 cover.html 的目录>     # 全流程：渲染 → 裁切 → 输出两图
CHROME_BIN=/path/to/chrome bash scripts/render_cover.sh ./whenfree   # 指定浏览器
```

| 参数 | 说明 |
|---|---|
| 第 1 参数 | 含 `cover.html` 与 `img/` 的文章目录 |
| 环境变量 `CHROME_BIN` | 浏览器可执行文件；缺省按 macOS Chrome → chrome-headless-shell 顺序探测 |

输出：`<dir>/img/cover.png`（1800×766，即 900×383@2x）、`<dir>/img/cover-square.png`（500×500）。
依赖：Chrome/Chromium、Python3 + Pillow。要求 `cover.html` 含 1800×766 头图区块与顶部间距 8px 的
1000×1000 方形区块（与本仓库范例同构）。

### 外部校验命令（阶段 6 门禁）

```bash
grep -n "——\|：" article-gzh.html            # 期望正文零命中（humanizer L1）
python3 <gzh-design>/scripts/validate_gzh_html.py article-gzh.html   # 期望全绿
```

## 示例

```bash
# 1. 渲染 whenfree 的头图
bash skills/kit-gzh-article-pipeline/scripts/render_cover.sh ~/Dev/github/holtwood/wechat-miniprogram/articles/whenfree

# 2. 发布前双门禁（在文章目录内）
grep -n "——\|：" article-gzh.html; python3 ~/.agents/skills/gzh-design/scripts/validate_gzh_html.py article-gzh.html
```

## 实现说明

- **依赖的外部 skill**（按名称装在 agent 的 skills 目录即可，本 skill 自动降级）：
  `humanizer`（写作红线与自检，核心）、`gzh-design`（排版组件库与校验脚本，核心）、
  `content-headline-hacker`（标题触发器）、`topic-pool`（选题池格式）
- **依赖的外部工具**：微信开发者工具 + wechatide CLI/MCP（截图）、Chrome/Chromium（渲染）、Python3 + Pillow（裁切）
- **产物工作区**：`articles/`，固定子结构见其 README.md（article.md / article-gzh.html /
  article-gzh-embedded.html / cover.html / img/）。工作区不在本仓库——它是随文章增长的数据
- **与 kit-capture / kit-shotframe 的边界**：本 skill 的截图走小程序模拟器（内容必须真实）；
  kit-capture 管网页/桌面截图，kit-shotframe 管套壳美化，三者可组合但不互相依赖

## 常见问题

- **自动化报 `page node not found`**：新开窗/刚刷新后立刻自动化所致。先 `simulator_refresh` 等 6 秒再操作
- **callMethod 挂死但退出码 0**：方法内部在等云端。改用 `automation_evaluate` 执行 `wx.navigateTo` 直达目标页
- **粘贴到公众号后图片丢失**：粘的是本地路径版。改用 `article-gzh-embedded.html`（base64 内嵌版，编辑器会自动转存）
- **校验脚本报 `ModuleNotFoundError: PIL`**：`pip3 install Pillow`（gzh-design 校验与头图裁切共同依赖）
