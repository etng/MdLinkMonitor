---
layout: default
title: MdMonitor Quick Capture Privacy Policy
permalink: /privacy/
---

<div class="shell page-shell">
<article class="prose" markdown="1">
# MdMonitor Quick Capture Privacy Policy

Effective date: 2026-06-17

MdMonitor Quick Capture is a browser extension that copies the current page as a Markdown link for use with MdMonitor. It is designed to work locally in your browser and with the clipboard on your computer.

## What the extension does

When you click the extension button, MdMonitor Quick Capture reads the active page URL and chooses a title from the page title, page headings, or URL path. It then formats that information as a Markdown link and writes it to your clipboard.

The extension options page lets you change the Markdown prefix and optionally grant access to all websites so the toolbar action works consistently across sites.

## Data handled by the extension

The extension may handle:

- The URL of the active page, only when you use the extension action.
- The active page title and visible heading text, only when needed to build the Markdown link.
- Local extension settings, including whether the prefix is enabled and the prefix text.
- The Markdown link copied to your clipboard.

MdMonitor Quick Capture does not collect account information, email addresses, payment information, authentication credentials, health information, precise location, or personal communications.

## Local storage and retention

Settings are stored locally in browser extension storage. They remain on your device until you change them, clear extension data, or uninstall the extension.

The generated Markdown link is written to your system clipboard. Clipboard retention is controlled by your operating system and any local apps you choose to run. If MdMonitor desktop is installed and clipboard monitoring is enabled, that local desktop app may read the copied Markdown link according to its own local settings.

## Data sharing

MdMonitor Quick Capture does not send page URLs, page titles, page content, settings, clipboard text, or usage events to the developer, Google Analytics, advertising networks, or third-party servers.

The extension does not use remote code. All executable code is included in the extension package.

## Permissions

MdMonitor Quick Capture requests only the permissions needed for its user-facing feature:

- `activeTab`: access the current tab after you click the extension button.
- `scripting`: read the current page title, headings, and URL to build the Markdown link.
- `clipboardWrite`: write the generated Markdown link to your clipboard.
- `storage`: save your local extension settings.
- `offscreen`: support clipboard writing in Chromium browsers.
- Optional access to all websites: lets the toolbar action work on ordinary web pages without repeated site-by-site prompts. Browser internal pages such as `chrome://` cannot be read.

## User control

You can change prefix settings from the extension options page. You can also revoke site access from your browser's extension details page or uninstall the extension at any time.

## Contact

For support or privacy questions, use the project issue tracker:

<https://github.com/etng/MdLinkMonitor/issues>

</article>
</div>
