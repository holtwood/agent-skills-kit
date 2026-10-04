# 平台与排错

| 模式 | Windows / WSL | macOS | Linux |
| --- | --- | --- | --- |
| 网页 | Chrome/Edge；WSL 使用 Linux 浏览器 | Chrome/Chromium | Chromium |
| 桌面 | PowerShell .NET；WSL interop 失败再降级 | screencapture | grim → X11 → gnome-screenshot |
| 窗口 | PowerShell 按标题/进程匹配 | JXA 获取窗口 ID | xdotool + import（X11） |
| 剪贴板 | PowerShell；WSL 可降级到 wl-paste/xclip | osascript，TIFF 可转 PNG | wl-paste → xclip，BMP 需转换 |

浏览器顺序为本机安装、已有 Playwright 缓存、PATH、已有下载缓存、下载 chrome-headless-shell。`KIT_SHOTFRAME_CHROMIUM` 或 `CHROME_PATH` 可指定可执行文件；缓存根目录遵循 `XDG_CACHE_HOME`，默认 `~/.cache/kit-capture/`。

- 黑屏：检查系统屏幕录制权限、显示会话与所用后端。
- Wayland 按名称截窗口不支持：截整屏并按用户需求裁切。
- 浏览器下载失败：检查网络或指定本机 Chrome。首次下载约 100MB，不写项目依赖。
- `interact` 缺运行时：需 Node/npm；puppeteer-core 安装到缓存的 `runtime/`，不是目标仓库。
- 选择器未命中：确认实际页面状态与 CSS 选择器；必要时等待可见元素。独立会话无法读取浏览器原有登录状态。
- 剪贴板只有 BMP 且无转换器：交付明确的失败状态与原始文件位置，不把 BMP 称为 PNG。
