---
layout: default
title: 使用指南
permalink: /guide/
---

<div class="shell page-shell">
<article class="prose" markdown="1">
<p class="eyebrow">MDMONITOR 使用指南</p>

# 安装一次，之后点一下就够了

MdMonitor 把“发现链接、记录链接、克隆仓库”连成一条自动流程。安装桌面端和浏览器扩展后，你在网页上点一下扩展按钮，当前页面就会进入当天的 Markdown；如果它是 Git 仓库，MdMonitor 还会执行你配置的命令。

<div class="guide-actions">
  <a class="button button-primary" href="https://github.com/etng/MdLinkMonitor/releases/latest/download/MdMonitor.dmg">下载桌面端</a>
  <a class="button button-secondary" href="https://chromewebstore.google.com/detail/mdmonitor-quick-capture/mpinigfoonemogokliifbaaelcolkjfi">安装 Chrome 扩展</a>
</div>

## 1. 安装并开启 MdMonitor

1. 下载 `MdMonitor.dmg`，把应用拖到 Applications。
2. 启动 MdMonitor，在菜单栏确认“启用监控”已经打开。
3. 保持应用在后台运行。后续收集不需要反复打开主窗口。

MdMonitor 默认把每天的链接写入 `links_yyyyMMdd.md`。你可以在设置中选择自己的输出目录。

## 2. 安装浏览器扩展

Chrome 用户可以直接安装已经公开发布的 [MdMonitor Quick Capture](https://chromewebstore.google.com/detail/mdmonitor-quick-capture/mpinigfoonemogokliifbaaelcolkjfi)。

安装后，把扩展固定到浏览器工具栏。浏览网页时点击按钮，扩展会生成下面这种内容：

```text
* [ ] [页面标题](页面网址)
```

MdMonitor 会从剪贴板接到这条链接，写入当天文件。同一天再次收集相同链接时会自动跳过。

<h2 id="repo-command">3. 让仓库自动执行命令</h2>

MdMonitor 默认识别 GitHub 和 GitLab 仓库。打开设置后，你可以调整三项内容：

- **仓库域名**：哪些网站的链接需要按代码仓库处理。
- **克隆命令模板**：识别到仓库后执行什么命令，模板中必须保留 `{repo}`。
- **克隆目录**：从哪个目录执行命令。

默认命令是：

```text
git clone {repo}.git
```

`{repo}` 会在执行前替换成仓库地址。你也可以改成已有的克隆脚本或其它自动化命令。这里配置的内容会直接在本机执行，请只使用自己确认过的命令。

## 不使用扩展也可以收集

只要复制的内容本身是 Markdown 链接，MdMonitor 同样会处理。对于不方便生成 Markdown 的网站，还可以在设置中加入“纯 URL 元数据白名单”，之后直接复制网址即可。

## 查看收集结果

打开 MdMonitor 主窗口后，你可以：

- 按日期查看每天收集的链接。
- 搜索标题或网址。
- 在渲染、双栏和源文件视图之间切换。
- 查看当天日志，确认链接为什么被记录、跳过或执行失败。

菜单栏图标也会短暂变色：绿色表示仓库命令已触发，蓝色表示链接已保存，橙色表示当天重复，红色表示后续处理失败。

<h2 id="automation">接入命令行和本地 API</h2>

如果你想继续自动化，可以在设置中安装 `mdm` 命令，读取当天记录或查看当前配置；也可以开启带 Token 的本地 REST API，让个人脚本主动提交链接。

- [查看 REST API 实战指南]({{ '/rest-api/' | relative_url }})
- [查看完整项目说明](https://github.com/etng/MdLinkMonitor)

## 没有按预期工作？

- **点击扩展后没有记录**：确认 MdMonitor 正在运行，并且“启用监控”已打开。
- **链接记录了但没有执行仓库命令**：检查仓库域名和克隆命令模板。
- **浏览器内部页面无法收集**：`chrome://` 等浏览器内部页面不允许扩展读取，这是浏览器的安全限制。
- **仍然无法判断原因**：打开主窗口查看今日日志，或到 [GitHub Issues](https://github.com/etng/MdLinkMonitor/issues) 反馈。

</article>
</div>
