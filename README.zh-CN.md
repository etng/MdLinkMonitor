# MdMonitor

English: [README.md](./README.md)

MdMonitor 是一个 macOS 菜单栏工具，用于从剪贴板收集 Markdown 链接。

开启监控后，复制形如 `[label](link)` 的内容会自动处理。对于加入白名单的域名，如果复制的是单个纯 URL，也会先抓取页面标题和简介再写入。

1. 追加到当天 markdown 文件。
2. 按配置域名识别 Git 仓库链接。
3. 对命中的仓库执行克隆命令模板。

默认克隆模板：`git clone {repo}.git`
默认克隆目录：`~/Documents/cbm/repos`

## 功能概览

- 菜单栏常驻，可开启/关闭监控。
- 当天去重（写入与克隆都去重）。
- 支持 `github.com`、`gitlab.com` 及自定义仓库域名。
- 支持为指定域名开启“纯 URL 抓取页面元数据”。
- 支持自定义克隆命令模板（必须包含 `{repo}`）。
- 支持配置克隆命令执行目录。
- 能识别 `mmbiz.qpic.cn` 的微信公众号图片附件，持久化保存到附件库，并且不写入每日 Markdown 链接。
- 会记录附件 MD5，可在配置的资源目录中匹配 `{md5}_MD.{ext}` 外部文件，并把黑名单写到 `blacklist.yaml`。
- 可选自动执行 `窗口 -> 合并所有窗口`，支持按 bundleId 定向（每行一个）。
- 每日 markdown 与日志按天保存。
- 主窗口支持渲染/双栏/源文件预览、附件库、日历跳转、今日日志排障。
- 内置 Sparkle 2 更新通道（非 App Store）。

## 默认输出

- 输出目录：`~/Documents/cbm`
- 当日 markdown：`links_yyyyMMdd.md`
- 当日日志：`logs_yyyyMMdd.log`
- 附件目录：`attachments/<sha1>.<ext>` 及同名元数据文件
- 附件黑名单：`blacklist.yaml`
- 行格式：`* [ ] [label](link)`
- 带简介时：`* [ ] [label](link) - summary`

## 安装

1. 从 Releases 下载 `MdMonitor.dmg`
2. 打开 DMG
3. 将 `MdMonitor.app` 拖到 `Applications`
4. 从 `Applications` 启动

如果 Gatekeeper 提示无法验证应用，可右键 `MdMonitor.app` -> `打开` -> 再次确认。

## 命令行（可选）

- 打开 **设置 -> 系统 -> 安装 mdm 命令**。
- 程序会把 `mdm` 安装到 `/usr/local/bin/mdm`。
- 若需要权限，macOS 会弹出管理员授权提示。
- 安装成功后，设置页会显示 `mdm 已安装`，并隐藏安装按钮。
- 终端验证：
  ```bash
  mdm help
  ```
- 常用命令：
  ```bash
  mdm today --path   # 输出今天 markdown 文件路径
  mdm today --print  # 输出今天 markdown 原文内容
  mdm status         # 输出当前设置快照
  mdm help           # 查看命令帮助
  ```

## 使用

1. 点击菜单栏图标，确保 `启用监控` 已打开。
2. 浏览时复制 Markdown 链接。
3. 对于不方便直接生成 Markdown 的特殊页面，可先把域名加入“纯 URL 元数据白名单”，然后直接复制页面 URL。
4. 从菜单打开主窗口：
   - 今天
   - 最近日期
   - 设置 / 帮助 / 更新
5. 在设置里配置：
   - 输出目录
   - 仓库域名
   - 纯 URL 元数据白名单
   - 附件资源目录
   - 克隆命令模板
   - 克隆目录
   - 自动合并窗口（可选 bundleId，每行一个）
   - 语言 / 通知 / 开机启动
   - 首次使用时，MdMonitor 会读取 Obsidian 当前或最近打开的 Vault，自动设置附件与 Daily 目录；之后也可以在设置中重新读取或手动选择。
6. 在预览页可以直接：
   - 暂停 / 恢复监控
   - 切换渲染 / 双栏 / 源文件
   - 对当前 Markdown 文件执行按域名排序
   - 打开附件库查看、预览和删除附件
   - 查看附件 MD5、外部资源匹配以及带黑名单的删除动作

## 捕获反馈颜色

当程序识别到可处理内容后，菜单栏图标会短暂变色。你不用打开日志或主窗口，瞄一眼颜色就能知道这次发生了什么。

- 绿色：识别为仓库，并已触发克隆。
- 蓝色：识别并已写入或保存，但这次不需要克隆。
- 橙色：识别到了，但因为当天重复或附件已存在而跳过。
- 灰褐色：识别到了，但被规则阻止，例如附件已在黑名单中。
- 红色：识别到了，但后续处理失败。请查看当日日志。

## 排障

- 剪贴板未捕获：
  - 确认监控已开启
  - 多链接模式关闭时，一次只复制一个 Markdown 链接
  - 纯 URL 需要先把域名加入白名单
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
