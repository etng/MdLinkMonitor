# MdMonitor Browser Extension

Cross-browser companion extension for MdMonitor.

It adds one fast action to your browser toolbar: copy the current page as a Markdown link that MdMonitor can collect directly.

## What It Does

- Click the toolbar button once
- Copy the current page as Markdown
- Keep the default MdMonitor-friendly format: `* [ ] [title](url)`
- Fall back from `document.title` to headings when the title is weak or empty

## Supported Browsers

- Chrome
- Edge
- Firefox

Safari is intentionally not included in this first release line.

## Install

The Chrome version is publicly available from the
[Chrome Web Store](https://chromewebstore.google.com/detail/mdmonitor-quick-capture/mpinigfoonemogokliifbaaelcolkjfi).

- Listing: MdMonitor Quick Capture
- Extension ID: `mpinigfoonemogokliifbaaelcolkjfi`

Edge and Firefox packages are available from the project's extension releases.

## Settings

Options page currently supports:

- One-time host permission grant for all sites
- Enable Prefix
- Prefix Text

Defaults:

- Site access: on-click temporary access
- Prefix enabled: `true`
- Prefix text: `* [ ] `

## Development

Install dependencies:

```bash
cd extension
npm install
```

Build:

```bash
npm run build
```

Package all supported browsers:

```bash
npm run zip:all
```

## Development Loading

Chrome / Edge:

1. Run `npm run build` or `npm run zip:chrome`
2. Open `chrome://extensions` or `edge://extensions`
3. Enable developer mode
4. Load the unpacked directory from `extension/.output/chrome-mv3` or `extension/.output/edge-mv3`

Firefox:

1. Run `npm run build:firefox` or `npm run zip:firefox`
2. Open `about:debugging`
3. Go to `This Firefox`
4. Load a temporary add-on from `extension/.output/firefox-mv2/manifest.json`

## Release

Extension releases are independent from the macOS app.

- App tags: `vX.Y.Z`
- Extension tags: `ext-vX.Y.Z`

The extension release workflow is defined in:

- [extension-release.yml](../.github/workflows/extension-release.yml)

It packages browser-specific zip files and publishes a dedicated GitHub release without taking over the repository's main app release line.
