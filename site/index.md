---
layout: default
title: 点一下，同时完成记录和克隆
body_class: home
---

<section class="product-hero">
  <div class="shell hero-layout">
    <div class="hero-copy">
      <p class="product-name">MdMonitor</p>
      <h1>点一下，同时完成记录和克隆</h1>
      <p class="hero-tagline">安装桌面端和浏览器扩展后，在网页点一下扩展按钮，当前链接就会按天记录；如果是 Git 仓库，还能自动克隆或执行你配置的其它命令。</p>
      <div class="hero-actions">
        <a class="button button-primary" href="https://github.com/etng/MdLinkMonitor/releases/latest/download/MdMonitor.dmg">下载桌面端</a>
        <a class="button button-secondary" href="https://chromewebstore.google.com/detail/mdmonitor-quick-capture/mpinigfoonemogokliifbaaelcolkjfi">安装浏览器扩展</a>
        <a class="button button-secondary" href="{{ '/guide/' | relative_url }}">查看使用指南</a>
      </div>
      <p class="hero-meta">macOS 13+ · 无需账号 · 免费开源</p>
    </div>

    <figure class="hero-shot">
      <img
        src="{{ '/assets/mdmonitor-preview.png' | relative_url }}"
        width="1960"
        height="1464"
        alt="MdMonitor 主窗口，正在预览当天收集的五条 Markdown 资料"
      />
      <figcaption>真实应用界面 · 公开演示数据</figcaption>
    </figure>
  </div>
</section>

<section class="home-section shell" id="features">
  <div class="section-intro">
    <h2>从点击扩展，到文件落地</h2>
    <p>浏览器扩展负责发起收集，桌面端负责记录和执行，一条链路完成原来需要切换窗口做的事。</p>
  </div>

  <div class="feature-grid">
    <article class="feature-card">
      <span class="feature-icon" aria-hidden="true">↗</span>
      <h3>在浏览器点击扩展</h3>
      <p>把当前页面的标题和网址整理成 Markdown 链接，不用手动复制和改格式。</p>
      <a href="https://chromewebstore.google.com/detail/mdmonitor-quick-capture/mpinigfoonemogokliifbaaelcolkjfi">Chrome 商店安装 →</a>
    </article>
    <article class="feature-card">
      <span class="feature-icon" aria-hidden="true">▤</span>
      <h3>自动按天记录</h3>
      <p>MdMonitor 监听到链接后写入当天的 Markdown，同一天重复收集会自动跳过。</p>
    </article>
    <article class="feature-card">
      <span class="feature-icon" aria-hidden="true">↳</span>
      <h3>对仓库自动执行命令</h3>
      <p>识别 GitHub、GitLab 或自定义仓库后，自动克隆，也可以执行你配置的其它命令。</p>
      <a href="{{ '/guide/#repo-command' | relative_url }}">配置仓库命令 →</a>
    </article>
    <article class="feature-card">
      <span class="feature-icon" aria-hidden="true">⌁</span>
      <h3>直接复制链接也能收集</h3>
      <p>没有安装扩展时，复制 Markdown 链接也能触发；指定网站还支持直接复制网址。</p>
    </article>
    <article class="feature-card">
      <span class="feature-icon" aria-hidden="true">◫</span>
      <h3>统一搜索和回看</h3>
      <p>在桌面端按日期打开记录、搜索标题或网址，也能继续整理图片附件。</p>
    </article>
    <article class="feature-card">
      <span class="feature-icon" aria-hidden="true">›_</span>
      <h3>接入自己的工作流</h3>
      <p>通过命令行读取当天记录，或让个人脚本使用本地 REST API 主动提交链接。</p>
      <a href="{{ '/guide/#automation' | relative_url }}">查看接入方式 →</a>
    </article>
  </div>

  <p class="local-note"><strong>本地优先：</strong>核心处理和文件都留在你的 Mac；浏览器扩展不上传页面内容或使用记录。</p>
</section>

<section class="extension-section" id="extension">
  <div class="shell extension-layout">
    <div class="extension-copy">
      <p class="section-label">MDMONITOR QUICK CAPTURE</p>
      <h2>从浏览器一键开始</h2>
      <p>扩展读取当前页面标题和网址，生成 MdMonitor 可以直接采集的 Markdown 链接。默认按点击临时授权，也可以主动开启全站权限。</p>
      <p class="store-status"><span aria-hidden="true"></span> Chrome Web Store 已公开发布</p>
      <div class="extension-actions">
        <a class="button button-primary" href="https://chromewebstore.google.com/detail/mdmonitor-quick-capture/mpinigfoonemogokliifbaaelcolkjfi">在 Chrome 中安装</a>
        <a class="text-link" href="{{ '/browser-extension/' | relative_url }}">权限与使用说明 →</a>
      </div>
    </div>
    <figure class="extension-shot">
      <img
        src="{{ '/assets/extension-options.png' | relative_url }}"
        width="1280"
        height="800"
        alt="MdMonitor Quick Capture 浏览器扩展设置页面"
      />
      <figcaption>Chrome / Edge / Firefox 共用一套实现</figcaption>
    </figure>
  </div>
</section>

<section class="home-section shell" id="download">
  <div class="download-box">
    <img src="{{ '/assets/app-icon.png' | relative_url }}" alt="" width="72" height="72" />
    <div>
      <h2>下载 MdMonitor</h2>
      <p>适用于 macOS 13 或更高版本。安装后从菜单栏开启监控即可使用。</p>
    </div>
    <a class="button button-primary" href="https://github.com/etng/MdLinkMonitor/releases/latest/download/MdMonitor.dmg">下载最新版</a>
  </div>
</section>
