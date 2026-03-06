---
layout: default
title: MdMonitor 博客
---

这里记录 MdMonitor 的产品思考、功能演进和发布说明。

<ul class="post-list">
{% for post in site.posts %}
  <li>
    <a class="post-title" href="{{ post.url | relative_url }}">{{ post.title }}</a>
    <div class="meta">
      {{ post.date | date: "%Y-%m-%d" }}
      {% if post.version %}
      · {{ post.version }}
      {% endif %}
    </div>
    <div>{{ post.excerpt | strip_html | truncate: 160 }}</div>
  </li>
{% endfor %}
</ul>
