---
layout: post
title: 为什么给 MdMonitor 再做一个浏览器扩展
date: 2026-03-14 16:20:00 +0800
version: ext-v0.1.1
---

MdMonitor 的桌面端已经能做采集、归档、搜索和回看，但真正的入口动作还差最后一截：在浏览器里把当前页面快速变成 Markdown 链接。

<!--more-->

如果这一步还要手动处理，链路里就始终会残留一个高频小动作：

1. 复制网址
2. 手动整理标题
3. 拼成 Markdown
4. 再回到 MdMonitor 的采集流程

这不算重，但它足够频繁，频繁到会把“浏览资料”的节奏切碎。

所以这次我把浏览器扩展补上了，目标很直接：

> 在浏览器里点击一次按钮，就把当前页面复制成 MdMonitor 可直接消费的 Markdown 链接。

## 这次为什么选浏览器扩展

桌面端监控剪贴板已经够用，但浏览器扩展能把动作再缩短一步：

- 不用手动选标题
- 不用手动拼 Markdown
- 不用在浏览器和其它工具之间切换

用户只需要点一下工具栏按钮，扩展就会直接复制：

```text
* [ ] [页面标题](当前网址)
```

然后 MdMonitor 桌面端继续负责：

- 自动采集
- 每日归档
- 搜索历史链接
- 回看当天资料

这条链路补完后，“发现资料 -> 记录 -> 后续检索”才算真正打通。

## 技术选型：为什么是 WXT

这次没有自己从零拼 WebExtension 构建链，而是直接用了 `WXT`。

原因很务实：

- 它本身就是围绕跨浏览器扩展开发设计的
- 目录结构和构建约定比较清晰
- Chrome、Edge、Firefox 可以共用同一套代码和打包流程
- 后面接 GitHub Actions 做 zip 构建也更顺手

我不想在这件事上重复造轮子。  
目标不是“研究一套扩展工程体系”，而是尽快把稳定可用的一键复制能力交付出来。

## 交互设计：为什么不做 popup

这次我刻意没有做 popup 主界面，而是选择：

- 工具栏按钮：直接执行复制
- Options 页面：只放配置

这样做的原因是操作更短。

如果还要先点按钮，再点 popup 里的“复制”，那本质上只是把一个动作拆成两个动作，没有意义。

所以第一版的主路径就是“一键完成”，配置只保留必要项：

- 是否一次授权所有网站
- 是否启用前缀
- 前缀文本是什么

默认仍然保持和 MdMonitor 桌面端一致的格式：`* [ ] `。

## 权限模型：为什么最后改成可选的全站授权

扩展刚做出来的时候，权限模型比较保守，只靠 `activeTab`。

这条路的优点是权限轻，浏览器不会一上来给一个很重的“读取所有网站”提示。  
缺点也很直接：对日常高频使用来说，用户会感觉自己在不同站点间反复被打断。

所以最后我把模型改成了两层：

1. 默认仍然用 `activeTab`
2. 但在 Options 页面提供一个“一次授权所有网站”的按钮

manifest 里对应的是：

```ts
export default defineConfig({
  manifest: {
    permissions: ["activeTab", "scripting", "storage"],
    optional_host_permissions: ["<all_urls>"]
  }
});
```

这样做的好处是，默认安装仍然保守；真正重度使用的人，可以自己在设置页点一次授权，把体验切成“后面基本都不再打断”。

请求权限的代码也不复杂：

```ts
const ALL_SITES_PERMISSION = {
  origins: ["<all_urls>"]
};

const granted = await browser.permissions.request(ALL_SITES_PERMISSION);
```

这个设计比“默认直接申请全部网站权限”更平衡，也更符合我对这个工具的定位：先把主流程做顺，再把权限放大交给用户主动决定。

## 标题兜底是这次实现里最需要想清楚的点

只拿 `document.title` 不够稳。

有些页面标题为空，有些页面标题质量很差，还有一些站点标题会把站点名和页面名混在一起。  
如果兜底直接退回域名，重复会很多，实际价值也很低。

所以最终顺序定成了：

1. `document.title`
2. 第一个有意义的 `h1`
3. 第一个有意义的 `h2`
4. 第一个有意义的 `h3`
5. URL 里最后一个有意义的 path segment
6. 最后才退回 hostname

这套规则不追求“百分之百语义完美”，目标是把“标题质量明显过低”的情况压到足够少。

## 这次开发里碰到的几个实际问题

### 1. 复制动作到底放在哪一层做

如果只在后台脚本里拼字符串，复制权限和兼容性会变得更绕。  
最后采用的是：点击扩展按钮后，注入一段很小的脚本到当前页面，在页面上下文里完成标题提取和复制。

这样做有两个好处：

- 更容易访问当前页面 DOM
- 标题和复制动作离页面上下文更近，逻辑更直接

另外还遇到一个实际问题：最初只用 `document.execCommand("copy")`，在工具栏点击后有些页面会直接返回 `false`。  
后面改成了“先试 `navigator.clipboard.writeText()`，失败再退回 `execCommand("copy")`”的双通道策略，稳定性明显更好。

### 2. 发布节奏不能和桌面端互相覆盖

MdMonitor 桌面端和浏览器扩展的发布频率不一定一样。  
如果共用同一条 release 语义，扩展发布很容易把桌面端的 release 节奏“盖过去”。

所以这次把扩展单独放进 `extension/` 子项目，并准备独立的 `ext-v*` 发布线。  
这样桌面端和扩展能各自演进，不互相干扰。

### 3. 文档和待办不能和主项目混在一起

这次我顺手把扩展自己的 PRD 和 TODO 也放进了 `extension/docs/`。

原因很简单：这已经不是“主项目里顺手加几行脚本”，而是一个独立的交付物。  
如果还把需求文档、发布思路、后续待办混在根目录，后面维护会越来越乱。

### 4. 发布链路之外，还顺手收了 GitHub Actions 的 Node 24 迁移

做扩展发布和站点文章时，顺手把 workflow 也看了一遍。  
GitHub Actions 这边已经在推进 Node 24 切换，仓库里一些 action 版本如果太旧，后面会越来越吵。

所以这次一起做了几件事：

- `actions/checkout` 升到 `v6`
- `actions/setup-node` 升到 `v6`
- `actions/upload-pages-artifact` 升到 `v4`
- Pages workflow 显式加了 `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24`

大致像这样：

```yaml
env:
  FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: "true"

steps:
  - uses: actions/checkout@v6
  - uses: actions/configure-pages@v5
  - uses: actions/upload-pages-artifact@v4
```

这里还有一个现实情况：GitHub 官方 Pages action 栈内部仍然会带出一条 Node 20 的 annotation。  
这个阶段仓库侧能做的常规升级已经做完了，剩下更多是官方 action 自己的演进问题，但至少这边已经不再拖后腿。

## 现在能做到什么

第一版扩展已经覆盖了几个核心点：

- Chrome / Edge / Firefox 共用一套实现
- 点击工具栏按钮即可复制 Markdown 链接
- Options 页面支持前缀开关和前缀文本保存
- 标题为空时会按 `title -> h1 -> h2/h3 -> path -> host` 兜底
- 可以独立打包浏览器安装包

Safari 这条线先不急着放进第一版，后面再单独处理打包和分发。

## 怎么安装

如果你想把这条链路完整跑起来，建议按下面顺序来：

1. 到项目的 [Releases 页面](https://github.com/etng/MdLinkMonitor/releases) 安装 MdMonitor 桌面端
2. 打开桌面端并开启监控
3. 安装对应浏览器的扩展

### Chrome

MdMonitor Quick Capture 已在 Chrome Web Store 公开发布：

- [前往 Chrome Web Store 安装](https://chromewebstore.google.com/detail/mdmonitor-quick-capture/mpinigfoonemogokliifbaaelcolkjfi)

### Edge

当前仍可使用发布包进行本地安装与验证：

1. 下载 Edge 扩展发布包并解压
2. 打开 `edge://extensions`
3. 开启开发者模式
4. 选择“加载解压缩的扩展”
5. 选中解压后的目录

### Firefox

Firefox 这条线当前先面向开发和验证：

1. 下载扩展发布包并解压
2. 打开 `about:debugging`
3. 进入 `This Firefox`
4. 选择 `Load Temporary Add-on`
5. 选择解压目录中的 `manifest.json` 或目录内任意扩展文件

如果后面要做稳定分发，还需要把 Firefox 的签名发布链路补上。

安装后建议先保持默认前缀 `* [ ] `，然后直接在网页里点击工具栏按钮。  
MdMonitor 桌面端会继续把内容收进当天文档，后面你就可以在桌面端里统一搜索和回看。

对我来说，这个扩展的意义不是“浏览器里多了一个按钮”，而是把整条资料收集链路真正缩短成了一个动作。

如果你本来就在用 MdMonitor，装上它之后，体验会完整很多。
