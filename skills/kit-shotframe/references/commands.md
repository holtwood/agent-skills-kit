# 渲染参数

路径中的 `<SKILL_ROOT>` 指本技能目录。输入仅支持 PNG。

## 渲染器契约

```bash
node <SKILL_ROOT>/scripts/frame.js \
  --input <截图路径> \
  --preset <browser|macos|device> \
  --output <输出路径.png|.pdf>
```

可选参数：

| 参数 | 说明 | 默认 |
| --- | --- | --- |
| `--preset` | `browser` 浏览器边框 / `macos` macOS 窗口框 / `device` 设备框 | `browser` |
| `--browser` | 浏览器框样式：`chrome` 标签页+地址栏 / `safari` 单行工具栏+居中地址胶囊（仅 `--preset browser` 时生效） | `chrome` |
| `--device` | 设备框机型：`iphone` / `ipad` / `macbook` / `galaxy` / `galaxy-flip` / `galaxy-fold`（仅 `--preset device` 时生效） | `iphone` |
| `--title` | 窗口标题（macOS 标题栏 / 浏览器标签页） | 不显示 |
| `--url` | 浏览器地址栏 URL | 不显示 |
| `--theme` | `auto` / `light` / `dark`——同时决定 chrome（标签页/标题栏）、外层背景与文案层的深浅配色；`auto` 按截图亮度自动选择 | `auto` |
| `--trim` | 裁掉输入四周与四角同色的**纯色空白边**（桌面背景/视口留白）后再套框；仅适用于裸截图。注意：应用自身的大片纯色空白区（如空白编辑区）也会被裁除，仅在确认四周空白是"多余画布"时使用 | 关闭 |
| `--bg` | 背景：命名渐变预设（`aurora`/`sky`/`sunset`/`ocean`/`lavender`/`forest`/`candy`/`slate`/`mono`，随 `--theme` 取深浅变体）、`solid:#0f172a`、`linear:#a8edea,#fed6e3`、`image:路径`（png/jpg/webp/gif 纹理或照片，cover 铺满）、`none`（透明） | 跟随 theme |
| `--angle` | 渐变角度（度）；对所有渐变背景生效，**包括内置主题背景** | `135` |
| `--ratio` | 画布比例：社媒（`og`/`linkedin`/`twitter`/`x`/`instagram`/`instagram-portrait`/`story`）、应用商店（`appstore-69`/`appstore-67`/`appstore-65`/`appstore-ipad`/`appstore-mac`/`play-phone`/`play-tablet`/`play-feature`/`ms-store`）或任意 `W:H` / `WxH`。**只扩画布不裁剪**，多出来的空间由背景填充 | 按内容 |
| `--width` | 目标输出宽度（px）。**只缩小不放大**；成功时宽度精确等于该值，无法做到时**明确失败**（`config/width-too-small`）或用 `warnings` 说明，绝不静默给别的尺寸。实现方式是按目标宽度直接渲染（缩小时缩放 CSS 场景，放大时调整设备像素比），而不是先出 2x 再整图缩小。对 `--format pdf` 无效 | 内容的 2 倍 |
| `--headline` | 画布顶部大字标题（随主题配色，字号按画布宽自适应，最多 2 行） | 不显示 |
| `--subcopy` | 标题下方一行副文案 | 不显示 |
| `--bleed` | 卡片底边出血：向下推出画布底缘裁掉——商店图"设备探出画面"的经典姿态。裸写 = 卡片高 10%，`--bleed 160` 指定 px | 关闭 |
| `--tilt` | 卡片倾斜角度（-30 ~ 30°，±2~3° 最有商店图感觉） | `0` |
| `--shadow` | 卡片投影档位：`none` / `soft`（更轻）/ `lifted`（更浮） | 跟随 theme |
| `--format` | `png` / `pdf`——pdf 走 Chromium printToPDF 输出**矢量**文件（外壳与文字矢量，内嵌截图仍是位图；`--width` 与透明背景对其无效） | `png` |
| `--inset` | 采样截图边缘最常见的颜色，在卡片内侧衬一圈同色衬边（px） | 关闭 |
| `--radius` | 卡片圆角（px，窗口/设备框） | 预设值 |
| `--transparent` | 输出透明背景 PNG（带 alpha，便于叠到任意底图上） | 关闭 |
| `--all` | 对每个背景预设各出一张；`--output` 作为基名（`out.png` → `out-aurora.png`…）。**一旦给了 `--all`，同时给的 `--bg` 会被忽略**（9 张已覆盖全部预设） | 关闭 |
| `--list` | 列出所有可用 preset / device / browser / theme / ratio / shadow / format / background 后退出（**不确定取值先跑这个**） | 关闭 |
| `--json` | 在 stdout 输出机读回执。成功与失败**顶层字段成套**：`ok` / `command` / `exitCode`（成功为 `0`）——可统一写 `if (!j.ok)` 判断，不会把成功误判成失败。成功另有 `canvas` / `outputs` / `warnings` / `format` / `copy`，失败有 `error.code` + `error.supportedFixes`；人类日志走 stderr | 关闭 |
| `--background` | （旧参数）等价于 `--bg light` / `--bg dark`，一般直接用 `--bg` | 跟随 theme |
| `--padding` | 设备/窗口四周留白（px） | `56` |
| `--chromium` | 指定 Chromium 可执行文件路径 | 自动探测 |


退出码：0 成功；1 环境或运行错误；2 参数错误；3 输出尺寸不符。

渲染使用临时文件，验证通过后再替换输出；失败保留已有结果。低于 1 倍的缩小采用 CSS 场景缩放与 DPR=1，避免浏览器钳制低设备像素比。
