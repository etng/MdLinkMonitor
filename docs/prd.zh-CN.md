# CBM 产品需求文档（PRD）

English version: [prd.md](./prd.md)

## 1. 产品目标

构建一个 macOS 菜单栏工具：当用户在剪贴板中复制 Markdown 链接且链接为 GitHub 仓库时，自动写入当天 markdown 文件，并触发仓库克隆。

## 2. 目标用户

- 经常在浏览网页、文档、社区时收集仓库链接的 macOS 开发者。

## 3. 用户故事

1. 作为用户，我希望 CBM 常驻菜单栏，并且可随时启用/禁用。
2. 作为用户，当我复制 `[label](https://github.com/owner/repo)` 时，能自动追加到当天笔记。
3. 作为用户，我希望命中后自动执行 `git c1 {repo}.git`。
4. 作为用户，我希望同一天内重复复制同仓库不会重复写入或重复 clone。
5. 作为用户，我希望可选开启“多链接处理”模式。
6. 作为用户，我希望在菜单里快速打开近期文件并预览。
7. 作为用户，我希望可选开机启动。
8. 作为用户，我希望默认中文界面，同时可切换英文。
9. 作为用户，我希望通过 CLI 获取今天的 markdown 路径或内容。
10. 作为用户，我希望使用 Sparkle 2 进行应用更新（非 App Store 分发）。

## 4. 功能需求

### 4.1 监控行为

- 应用以菜单栏形态运行。
- 仅在“启用监控”开启时处理剪贴板。
- 关闭时不解析、不写文件、不执行命令。

### 4.2 剪贴板解析

- 输入来源：剪贴板文本。
- 主模式：Markdown 链接 `[label](link)`。
- 默认仅处理“恰好一个链接”的内容。
- 开启 `Allow Multiple Links` 后可处理多个链接。

### 4.3 GitHub 仓库 URL 规则

- 仅接受 `https://github.com/owner/repo`。
- 忽略 query 与 hash。
- 规范化为 `https://github.com/owner/repo`。
- 兼容末尾 `/` 与 `.git`。

### 4.4 持久化

- 输出目录可配置。
- 默认目录：`~/Documents/cbm`。
- 每日文件名：`links_yyyyMMdd.md`。
- 追加行格式：`* [ ] [label](https://github.com/owner/repo)`。

### 4.5 去重策略

- 去重范围：当天。
- 去重键：规范化仓库标识（`owner/repo`）。
- 当天同仓库不得重复：
  - 写入 markdown
  - 触发 clone

### 4.6 克隆命令

- 命中且非重复时执行：`git c1 {repo}.git`。
- `{repo}` 为不带 `.git` 的规范化 HTTPS URL。

### 4.7 UI 与设置

- 菜单项包含：
  - Enable Monitoring
  - Enable Notifications
  - Allow Multiple Links
  - Launch at Login
  - Output Directory
  - Language（中文 / English）
  - Recent Files（直接展示最近 7 天）
  - About
- 点击近期文件可打开预览窗口。
- 预览窗口：
  - 左侧历史文件列表
  - 右侧 Markdown 渲染
  - 提供“复制 Markdown 原文”按钮

### 4.8 CLI

- 提供命令行能力：
  - 输出今天文件路径
  - 输出今天文件内容

### 4.9 更新机制

- 使用 Sparkle 2（非 App Store）。
- 更新失败默认静默，仅写日志。

### 4.10 通知与日志

- 支持系统通知反馈（可开关）：
  - 识别/写入/克隆结果
  - 关键设置动作结果
- 写入每日日志到输出目录：
  - 文件名：`logs_yyyyMMdd.log`
  - 每行包含时间戳、级别、消息
  - 包含 markdown 写入成功记录

## 5. 非功能需求

- 平台：macOS（Swift + SwiftUI）。
- 可靠性：剪贴板轮询轻量稳定。
- 安全性：通过当天去重防止重复 clone。
- 国际化：默认中文，支持英文。

## 6. 当前迭代范围外

- 跨设备同步。
- 历史文件全文检索。
- 自定义 clone 命令模板（后续可做）。

## 7. 验收标准

1. 启用监控后，复制一个合法仓库链接：追加一行并执行一次 clone。
2. 同日重复复制同仓库：不重复写入、不重复 clone。
3. 非 GitHub 仓库链接：不处理。
4. 多链接模式关闭时，多链接内容被忽略。
5. 多链接模式开启时，所有合法仓库按当天去重处理。
6. CLI 可输出今天路径与内容。
7. 菜单直接显示最近 7 天文件，并可打开预览。
8. 预览窗口可左侧浏览历史文件并右侧渲染 Markdown。
9. 可中英文切换。
10. Sparkle 可手动触发检查更新，失败静默记录日志。
