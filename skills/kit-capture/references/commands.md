# 截图命令参数

用 `bash <SKILL_ROOT>/scripts/capture.sh MODE ...`。输出目录自动创建。

| 模式 | 参数 |
| --- | --- |
| `browser URL` | `-o FILE`、`--width 1440`；视口高 1200 |
| `interact URL` | `-o FILE`、`--width 1440`、`--height 900`、`--dsf 1`、`--selector CSS`、`--fullpage` |
| `screen` | `-o FILE` |
| `window QUERY` | `-o FILE`；标题/进程子串匹配依平台而定 |
| `clip` | `-o FILE` |

交互动作按参数出现顺序执行，可重复：`--click CSS`、`--wait MS`、`--waitfor CSS`、`--scroll PX`。优先等待目标元素而非猜测加载时间；`--wait 0` 与 `--scroll 0` 是有效的零动作。

```bash
bash <SKILL_ROOT>/scripts/capture.sh interact https://example.com \
  --waitfor '#menu' --click '#menu' --waitfor '#panel' --selector '#panel' -o ./panel.png
bash <SKILL_ROOT>/scripts/capture.sh interact https://example.com --fullpage --dsf 2 -o ./full.png
```

宽/高为正整数，dsf 为正数。未知参数和缺失参数退出 2，配置错误在下载浏览器之前检查。`browser` 只截视口；整页需要 `interact`。
