# MdMonitor

English: [README.md](./README.md)

MdMonitor 是一个 macOS 菜单栏工具，用于从剪贴板收集 Markdown 链接。

开启监控后，复制形如 `[label](link)` 的内容会自动处理：

1. 追加到当天 markdown 文件。
2. 按配置域名识别 Git 仓库链接。
3. 对命中的仓库执行克隆命令模板。

默认克隆模板：`git clone {repo}.git`
默认克隆目录：`~/Documents/cbm/repos`

## 功能概览

- 菜单栏常驻，可开启/关闭监控。
- 当天去重（写入与克隆都去重）。
- 支持 `github.com`、`gitlab.com` 及自定义仓库域名。
- 支持自定义克隆命令模板（必须包含 `{repo}`）。
- 支持配置克隆命令执行目录。
- 每日 markdown 与日志按天保存。
- 主窗口支持预览、日历跳转、今日日志排障。
- 内置 Sparkle 2 更新通道（非 App Store）。

## 默认输出

- 输出目录：`~/Documents/cbm`
- 当日 markdown：`links_yyyyMMdd.md`
- 当日日志：`logs_yyyyMMdd.log`
- 行格式：`* [ ] [label](link)`

## 安装

1. 从 Releases 下载 `MdMonitor.dmg`
2. 打开 DMG
3. 将 `MdMonitor.app` 拖到 `Applications`
4. 从 `Applications` 启动

如果 Gatekeeper 提示无法验证应用，可右键 `MdMonitor.app` -> `打开` -> 再次确认。

## 使用

1. 点击菜单栏图标，确保 `启用监控` 已打开。
2. 浏览时复制 Markdown 链接。
3. 从菜单打开主窗口：
   - 今天
   - 最近日期
   - 设置 / 帮助 / 更新
4. 在设置里配置：
   - 输出目录
   - 仓库域名
   - 克隆命令模板
   - 克隆目录
   - 语言 / 通知 / 开机启动

## 排障

- 剪贴板未捕获：
  - 确认监控已开启
  - 多链接模式关闭时，一次只复制一个 Markdown 链接
  - 查看输出目录下当日日志
- 写入了但没克隆：
  - 链接未命中仓库域名/路径规则
- Spotlight 打开到旧版本：
  - 建议只保留一个安装位置（优先 `/Applications`）
  - 必要时运行 `make refresh-launch-services APP_PATH=/Applications/MdMonitor.app`

## 许可证与鸣谢

- 许可证：[MIT](./LICENSE)
- 第三方组件鸣谢：[docs/acknowledgements.md](./docs/acknowledgements.md)

## 贡献与发布

开发与发布流程见 [docs/contribution.md](./docs/contribution.md)。
