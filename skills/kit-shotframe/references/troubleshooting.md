# kit-shotframe · 排错参考（常见问题）

渲染失败或结果不对时按 `error.code` / 退出码对号入座。主契约见 `../SKILL.md`。

- **找不到 Chromium**（`environment/chromium-missing`）：`sudo apt install chromium` 或安装 playwright 后重试；也可显式 `--chromium /path/to/chrome`
- **输出全是空白**：检查输入 PNG 是否损坏；`file input.png` 确认格式
- **退出码 3（输出尺寸不符）**：无头窗口被显示环境钳制（屏幕/虚拟显示过小）——换更大的虚拟屏（如 Xvfb 调大分辨率）或减小输入截图宽度后重试
- **`output/missing`（Chromium 退出但没产出文件）**：说明那个 `chromium` 其实不可用——常见于 PATH 上的壳脚本/转发器（转发器可能退出码 0 却未生成截图）。用 `--chromium /path/to/real/chrome` 指向真实浏览器，或先 `chromium --version` 验证
- **主题误判**（如浅色 UI 内嵌大片深色图片、截图带大面积空白边）：auto 按画面亮度判断，极端构图可能选错主题——显式加 `--theme light` 或 `--theme dark` 覆盖
- **`--trim` 裁多了/裁少了**：该参数只面向「四周为纯色空白边」的裸截图；应用自身的纯色空白区（空白编辑器/纯色画布）也会被视为边而裁除，渐变背景则会因超容差而停止——不确定时不用它
- **`--ratio` 之后图变大了、四周多了留白**：这是设计如此——`--ratio` **只扩画布不裁剪**，保证内容完整。想要裁切请先自行裁图，或用 `--trim` 去掉纯色空白边
- **`--width` 没把图放大**：该参数**只缩小不放大**。想要比 2x 画布更宽时不会静默处理——回执的 `warnings` 会写明实际输出宽度；需要更大请提高输入截图分辨率
- **`config/width-too-small`**：`--width` 小到低于可用缩放下限（`--ratio` 会把画布撑得很大，从而压低可用缩放比）。报错信息里给了当前画布下**最小可输出宽度**，照它调大即可；或去掉 `--ratio`、先自行缩小输入截图
- **`config/canvas-too-large`**：极端 `--ratio`（如 `100:1`）或 `--padding` 会算出天文数字的画布，超出单边上限 16000px。**会在 1 秒内失败**并提示，而不是让 Chromium 空转 60 秒超时再报一个含糊错误
- **`config/output-too-large`**：输出像素总量超过 ≈120MP。用 `--width` 指定更小的宽度，或减小 `--ratio` / `--padding`
- **`config/invalid-inset`**：`--inset` 大到把画面吃光（窗口预设按截图宽度算，`device` 预设按设备屏幕宽度算，如 iPhone 只有 390px）。按提示取小于一半的值
- **`config/invalid-tilt`**：`--tilt` 超出 ±30°（或不是数字）。商店图建议 ±2~3°
- **`config/invalid-bleed`**：`--bleed` 带了非整数值或负数。裸写 `--bleed` 自动取卡片高 10%，或给非负整数 px
- **`config/unknown-format` / `unknown-shadow`**：`--format` 只支持 `png`/`pdf`，`--shadow` 只支持 `none`/`soft`/`lifted`——先跑 `--list` 拿合法取值
- **`--bg` 报未知取值**（`error.code = config/unknown-background`）：先跑 `--list` 拿全部合法预设名，不要猜；`image:` 形式的常见原因是**路径不存在**或扩展名不在 png/jpg/jpeg/webp/gif 里
- **数值参数报错**（`config/invalid-padding` / `invalid-width` / `invalid-angle` / `invalid-inset` / `invalid-radius`）：数值参数写错**不会静默回退到默认值**（比如 `--padding 5O` 里是字母 O，会直接报错，而不是悄悄按 56 渲染）。按报错信息改成合法数字即可
- **`--transparent` 出来仍是白底**：透明只在没有背景时成立——不要同时给 `--bg solid:` 之类的实色背景；输出应为 RGBA（32 位带 alpha）
- **`--format pdf` 的相关告警**：`--width` 对矢量 PDF 无意义（忽略）；`--transparent`/`--bg none` 无效（打印铺白底）；PDF 尺寸 = 画布 CSS 尺寸，内嵌截图仍是位图
- **`--headline` 文字太小/换行奇怪**：标题字号按画布宽度 7.5% 估算、超长按 CJK≈1/拉丁≈0.56 字宽收缩到单行，最多 2 行。文案过长时缩短内容并检查实际排布
- **`--all` 的文件去哪了**：以 `--output` 为基名派生，`out.png` → `out-aurora.png`、`out-sky.png` …；`--json` 回执的 `outputs[]` 里有完整路径
- **想更清晰**：默认输出已是 2x，README 中建议 `<img width="900">` 展示
