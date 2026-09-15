# 值得关注的外部 Skills（备忘录）

这里只记录**链接和用途**，不把第三方代码放进本仓库。

原因：vendored 进来就得跟着上游走 —— 每次同步都要重新校验、重新打补丁，release 资产还可能顺带删掉仓库里已有的文件（比如测试目录），维护成本远大于收益。想用的时候单独装一份就行。

## 清单

### archify

- 链接：[tt-a1i/archify](https://github.com/tt-a1i/archify)
- 用途：架构 / 流程 / 时序 / 数据流 / 状态图，输出自包含 HTML + SVG，支持主题切换与导出
- 许可：MIT
- 备注：2026-09 试用过 v2.16.0，能力确实强；但官方更新频繁，所以只记链接、不 vendor

<!-- 继续往下加：复制上面的小节，改链接 / 用途 / 许可 / 备注即可 -->

## 怎么装

第三方 skill 装到本机 skill 目录即可，**不要放进本仓库**：

- Claude Code：`~/.claude/skills/`
- opencode：`~/.config/opencode/skills/`

本仓库的 `install.sh` / `install.ps1` 只管理 `skills/` 下的自研 skill，不会碰到上面这两个目录里的第三方 skill。
