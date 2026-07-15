# Pages Source

This folder contains the GitHub Pages product site and build log for MdMonitor.

- `index.md`: product home page and ecosystem overview
- `_posts/`: blog posts
- `_layouts/default.html`: base layout
- `assets/styles.css`: site style

Deployment is handled by `.github/workflows/pages.yml` using GitHub Actions Pages workflow (build + deploy).

## 本地验证

以下命令使用与 GitHub Pages 兼容的 Jekyll 4.2.2 构建到 `/tmp`，不会在仓库里留下 `_site` 或缓存：

```bash
rm -rf /tmp/mdmonitor-jekyll-site
mkdir -p /tmp/mdmonitor-jekyll-site
docker run --rm --platform linux/amd64 \
  -v "$PWD/site:/srv/jekyll:ro" \
  -v "/tmp/mdmonitor-jekyll-site:/srv/_site" \
  jekyll/jekyll:4.2.2 \
  jekyll build --disable-disk-cache --source /srv/jekyll --destination /srv/_site
```

如需按线上 `baseurl` 预览：

```bash
rm -rf /tmp/mdmonitor-preview
mkdir -p /tmp/mdmonitor-preview
ln -s /tmp/mdmonitor-jekyll-site /tmp/mdmonitor-preview/MdLinkMonitor
python3 -m http.server 4173 --directory /tmp/mdmonitor-preview
```
