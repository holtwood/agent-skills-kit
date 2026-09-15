# shotframe · 设计参考（预设 / 背景 / 画布 / 实现说明）

主契约见 `../SKILL.md`。本文件是按需细读部分：选 preset 时看「预设说明」，调背景/画布看「背景与画布」，做商店图看「商店图构图」，好奇实现边界看「实现说明」。

## 预设说明

- **`macos`**：圆角窗口 + 居中标题栏 + 红黄绿信号灯 + 柔和投影（深浅两套配色）
- **`browser`**：标签页 + 地址栏（锁图标 + URL）+ 同款投影（深浅两套配色）；`--browser safari` 换为 Safari 风格单行工具栏（信号灯 + 居中地址胶囊）
- **`device`**：按机型渲染真实感设备框——`iphone` 灵动岛 + home 指示条 + 侧边按键，`ipad` 顶部摄像头 + home 指示条，`macbook` 铝制机身 + 屏幕刘海 + 底部下巴（含 Apple logo），`galaxy`/`galaxy-flip` 屏内居中打孔前摄 + 右侧音量/电源键 + 手势条，`galaxy-fold` 展开态近方形屏 + 右上打孔 + 中缝铰链线。截图按设备屏幕宽度等比缩放填充

## 背景与画布

- **背景**：默认跟随 `--theme`（深浅两套内置背景）。想更出彩用 `--bg <预设>`（9 组渐变预设，各有深浅变体，随 `--theme auto` 自动选）；要精确控制用 `--bg solid:#0f172a` 或 `--bg linear:#a8edea,#fed6e3`（可配 `--angle`）；要照片/纹理质感用 `--bg image:路径`（png/jpg/webp/gif，center/cover 铺满）。
- **社媒画布**：`--ratio og` / `--ratio twitter` / `--ratio instagram` / `--ratio instagram-portrait` / `--ratio story`，或任意 `--ratio 16:9`。规则是**只扩画布不裁剪**——内容始终居中且完整保留，多出来的空间由背景填充；再配 `--width 1200` 落到平台推荐尺寸（`--width` 只缩小不放大）。
- **商店画布**：`--ratio appstore-69`（1320×2868，iPhone 6.9"）/ `appstore-67` / `appstore-65` / `appstore-ipad`（2064×2752）/ `appstore-mac` / `play-phone`（1080×1920）/ `play-tablet` / `play-feature`（1024×500）/ `ms-store`。配合 `--width` 落到官方像素，如 `--ratio appstore-69 --width 1320` 输出恰好 1320×2868。
- **边缘色衬边**：`--inset 12` 采样截图四周最常见的颜色，在卡片内侧衬一圈同色边，让「截图自带留白」和「卡片」自然衔接。区域截图通常已有自身边距，可以不开。
- **透明底**：`--transparent`（等价 `--bg none`）输出带 alpha 的 PNG，方便叠到 PPT / 任意底图上。对 `--format pdf` 无效（打印铺白底）。
- **挑风格**：`--all` 一次出全部 9 个背景预设（`--output out.png` → `out-aurora.png` …），从里面挑一张再精修。

## 商店图构图（--headline / --bleed / --tilt / --shadow）

App Store / Google Play 风格营销图的三个招牌手法：

- **文案层**：`--headline "大字标题"`（顶部居中，字号按画布宽度取 7.5% 自动适配，超长自动收缩/换行最多 2 行）+ `--subcopy "一行副文案"`。颜色随主题（深底白字/浅底深字）。文案层占高会先并入画布再算 `--ratio`，与设备框共存时自动上下排布。
- **底边出血**：`--bleed` 把卡片向下推出画布底缘（裸写 = 卡片高 10%，或 `--bleed 160` 指定 px），超出部分被裁掉——商店图里设备"探出画面"的经典姿态。
- **微倾**：`--tilt -2` 给卡片一个轻旋转（-30~30°，推荐 ±2~3°）。多张成组时可交替 -2/+2 制造节奏感。
- **阴影档位**：`--shadow soft`（更轻）/ `--shadow lifted`（更浮、更"飘"）/ `--shadow none`。默认随主题，一般不用动；出血+倾斜构图配 `lifted` 更有层次。

典型组合（商店首图）：

```bash
node scripts/frame.js --input shot.png --preset device --device galaxy \
  --ratio appstore-69 --width 1320 \
  --headline "把截图变成产品图" --subcopy "零依赖 · 确定性渲染" \
  --bleed --tilt -2 --shadow lifted \
  --output store-01.png
```

## 实现说明

- **零 npm 依赖**：渲染 = Node 标准库生成 HTML + 系统 Chromium 无头截图（`--force-device-scale-factor=2` 保证清晰度）
- **主题自适应**：内置零依赖 PNG 解码器（仅 8-bit 非隔行），`--theme auto` 按**裁剪后区域**的全图采样亮度自动选择深/浅整套配色（chrome + 背景 + 描边 + 投影）；解码失败回退 light 并提示
- **`--trim`**：同一解码器检测四角同色的均匀空白边（容差收紧防误裁渐变，每边最多裁 20%），像素级裁剪后重封装 PNG 再进渲染流程
- **背景预设**：9 组渐变各含 light/dark 两套停靠点，随 `--theme` 选变体；`--bg solid:` / `linear:` 走同一套 CSS 生成，`image:` 把文件内联成 data URI（base64），均无额外依赖
- **`--ratio`**：在「内容 + 文案层 + 留白」的基础上按比例**只扩不裁**（内容居中，多出的空间由背景填充）
- **`--width`**：按目标宽度调节 Chromium 的设备像素比**直接渲染**（chrome 文字按目标分辨率排版，不是先出 2x 再整图缩小）；因此宽度能精确兑现，低于可用缩放下限时明确报错而非静默改尺寸。注意内嵌的截图仍由浏览器合成器等比缩放
- **`--format pdf`**：改走 Chromium `printToPDF`，`@page` 按画布 CSS 尺寸输出**矢量**文件（外壳与文字是矢量，内嵌截图仍是位图）。`--width` 对其无意义（已忽略并告警），透明背景同样无效
- **文案层排版**：`copyLayout` 按画布宽度估算标题字号（CJK≈1、拉丁≈0.56 字宽单位），先收缩到单行，放不下最多 2 行；占高并入画布计算，不做迭代收敛——极端长文案可能留白偏多，缩短文案比依赖自动适配更稳
- **`--bleed` / `--tilt`**：纯 CSS `transform: translateY + rotate` 作用在卡片根节点，画布尺寸不变、溢出部分被 `overflow:hidden` 裁掉
- **`--inset`**：复用零依赖 PNG 解码器，按外围像素量化统计出边缘主色，作为卡片内侧衬边色
- **尺寸校验**：PNG 输出应为逻辑尺寸 × 设备像素比；不符时按差值校正窗口尺寸自动重试一次（容差 ±1px，兼容小数像素比），仍不符以退出码 3 失败（防御无头窗口被显示环境钳制）。PDF 输出改为校验 `%PDF-` 文件头
- **机读契约**：`--json` 在 stdout 输出回执（成功 `ok:true` + `canvas`/`outputs`；失败 `ok:false` + `exitCode` + `error.code` 稳定 slug），人类日志走 stdout 之外的通道，便于 agent 直接解析
- 设备框为纯 CSS 绘制（机身 / 灵动岛 / 刘海 / 按键 / logo 均为样式实现），截图按设备屏幕宽度等比缩放填充，不拉伸变形
- Chromium 自动探测顺序：`SHOTFRAME_CHROMIUM` 环境变量 → Playwright 缓存目录 → `wsl-capture` 自举下载的 chrome-headless-shell 缓存（`~/.cache/wsl-capture/`）→ `which chromium / google-chrome / chrome`；识别到 chrome-headless-shell 时自动改用旧版 headless 开关
- 输入格式：PNG（自动读取宽高，无需额外库）
- 默认输出 2 倍尺寸（等价 Retina）；需要落到平台推荐宽度时用 `--width`（只缩小），README 里也可再 `width=` 限制显示
