# MdMonitor

English version: [README.md](./README.md)

MdMonitor 是一个使用 Swift 开发的 macOS 菜单栏应用。

当开启监控后，它会监听剪贴板中的 Markdown 链接 `[label](link)`。MdMonitor 会：

1. 将去重后的任务行追加到当天 markdown 文件。
2. 按可配置域名识别 Git 仓库链接（如 `github.com`、`gitlab.com`）。
3. 对命中的仓库链接进行 URL 规范化（忽略 query/hash，处理末尾 `/` 和 `.git`）并执行 `git c1 {repo}.git`。

## 核心功能

- 菜单栏应用，可一键启用/禁用监控。
- 系统通知可开关。
- 可选开机启动。
- 默认中文界面，支持切换英文。
- 每日输出 markdown 到可配置目录（默认 `~/Documents/cbm`）。
- 同目录写入每日日志（`logs_yyyyMMdd.log`）。
- 当天去重（写入与 clone 都去重）。
- 非仓库 Markdown 链接也会写入（但不会 clone）。
- 仓库识别支持可配置域名（默认 `github.com`、`gitlab.com`）。
- 支持可选多链接处理模式。
- 菜单直接展示最近 7 天文件。
- 设置项迁移到独立设置窗口。
- 预览窗口支持左侧历史文件列表，点击切换预览。
- 预览窗口支持复制 Markdown 原文。
- 预览今天文件时，底部提供默认折叠且自动刷新的今日日志面板。
- CLI 支持获取今天文件路径与内容。
- 非 App Store 更新机制使用 Sparkle 2。

## 默认输出

- 目录：`~/Documents/cbm`
- 文件名：`links_yyyyMMdd.md`
- 行格式：`* [ ] [label](https://example.com/path)`
- 日志文件：`logs_yyyyMMdd.log`

## 开发

- Swift: 6+
- 平台：macOS
- 构建：`swift build`
- 测试：`swift test`
- 运行 CLI：`swift run cbm help`
- 运行菜单栏应用：`swift run MdMonitor`

## 打包与发布（命令行）

推荐直接使用 Makefile：

```bash
make app           # 构建 dist/MdMonitor.app
make dmg           # 构建 dist/MdMonitor.dmg
make install       # 安装到 /Applications（可通过 INSTALL_DIR 覆盖）
make install-local # 安装到 ~/Applications
```

若当前环境不支持 `hdiutil`，`make dmg` 会自动回退生成 `dist/MdMonitor.zip`。
`make app` 会自动把 `Sparkle.framework` 嵌入到 `Contents/Frameworks`。

如果你已经有导出的 `.app`，也可以手工打包 `.dmg`：

```bash
mkdir -p dist/dmg
cp -R dist/MdMonitor.app dist/dmg/
hdiutil create \
  -volname "MdMonitor" \
  -srcfolder dist/dmg \
  -ov \
  -format UDZO \
  dist/MdMonitor.dmg
```

## CLI

- `cbm today --path`：输出今天 markdown 文件路径。
- `cbm today --print`：输出今天 markdown 文件内容。
- `cbm status`：输出当前设置快照。

## 架构

- `Sources/CBMCore`：解析、URL 规范化、每日存储、去重、剪贴板流程、设置、clone 执行器。
- `Sources/CBMMenuBar`：菜单栏 UI、设置、预览窗口、开机启动、Sparkle 更新入口。
- `Sources/cbm`：CLI 入口。
- `Tests/CBMCoreTests`：核心逻辑单测。

## 说明

- 当前版本 clone 命令固定为 `git c1 {repo}.git`。
- 去重范围是“当天内去重”。
- Sparkle 更新需要正确签名与 appcast 配置。
- 更新失败会静默处理，仅写入当日日志。
- 开发环境下 `Launch at Login` 可能因签名/Bundle 限制失败。
- 使用 `swift run MdMonitor` 启动时，系统通知会自动禁用（避免非 .app 环境崩溃）。

## 排障

- 若剪贴板看起来没有被捕获：
  - 确认菜单中 `启用监控` 已开启。
  - 在未开启多链接模式时，一次仅复制一个 Markdown 链接。
  - 查看当日日志：`~/Documents/cbm/logs_yyyyMMdd.log`（或你配置的输出目录）。
  - 成功写入时，日志会出现 `已写入 markdown: ...`。
  - Debug 构建会输出 `[event]` 前缀的 UI 事件日志。
- 若链接未命中仓库域名：
  - 仍会写入 markdown。
  - 会跳过 clone（设计如此）。
- 若点击菜单项后只听到提示音没有弹窗：
  - 更新到最新版本，当前逻辑已改为菜单关闭后异步触发动作。

## 开发诊断

- 详细事件日志开关：`Diagnostics.verboseEventLogging`
- 文件：`Sources/CBMMenuBar/Diagnostics.swift`
- 默认策略：
  - `DEBUG`：开启
  - 非 `DEBUG`：关闭

## 当前状态

参见：

- PRD（中文）：`docs/prd.zh-CN.md`
- PRD（English）：`docs/prd.md`
- 待办看板：`docs/todo.md`
