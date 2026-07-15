# MdMonitor Browser Extension PRD

## 1. Product Goal

Provide a cross-browser extension that lets users copy the current page as a Markdown link in one click, so the copied content can flow directly into MdMonitor without interrupting browsing.

## 2. Target Users

- Users who already use MdMonitor to collect links and review them later.
- Users who want a faster capture path than manual Markdown formatting.

## 3. User Stories

1. As a user, I want to click one browser toolbar button and immediately copy the current page as a Markdown link.
2. As a user, I want the copied output to keep my existing MdMonitor format, including the default prefix `* [ ] `.
3. As a user, I want simple settings for whether the prefix is enabled and what the prefix text is.
4. As a user, I want the extension to fall back to page headings when `document.title` is empty or poor.
5. As a user, I want the options page to explain that the extension is designed to work with MdMonitor desktop.

## 4. Functional Requirements

### 4.1 Core Action

- Extension provides a toolbar button.
- Clicking the button copies one Markdown link for the active tab.
- Default output format is `* [ ] [title](url)`.
- If prefix is disabled, output becomes `[title](url)`.

### 4.2 Title Resolution

- Resolve title using this order:
  1. `document.title`
  2. first meaningful `h1`
  3. first meaningful `h2`
  4. first meaningful `h3`
  5. last meaningful path segment from URL
  6. hostname as final fallback
- Ignore empty or obviously weak values where possible.

### 4.3 Settings

- Options page includes:
  - `Grant All Sites Access` action, optional
  - `Enable Prefix` toggle, default `true`
  - `Prefix Text` input, default `* [ ] `
  - `Save` button
- Settings are stored locally inside browser extension storage.
- Default access model stays conservative (`activeTab` on click).
- Users can upgrade to one-time all-sites authorization when they want smoother daily use.

### 4.4 Supported Browsers

- First-class packaging targets:
  - Chrome
  - Edge
  - Firefox
- Safari is out of scope for the first iteration.

### 4.5 Product Positioning

- Options page must describe that the extension is a companion to MdMonitor desktop.
- Options page must link users to the project Releases page for installation assets.

## 5. Non-Functional Requirements

- Use a common cross-browser extension framework.
- Keep required permissions minimal.
- Build output should be scriptable in CI for browser-specific zip packaging.

## 6. Out of Scope

- Popup UI for main action
- Full template editor beyond prefix
- Browser-side history or archive browsing
- Safari release packaging

## 7. Acceptance Criteria

1. Clicking the toolbar button on a normal web page copies a Markdown link.
2. Default copy result includes the configured prefix.
3. Turning off prefix removes the prefix from copied text.
4. Empty page titles fall back to headings before falling back to URL path or host.
5. `npm run build` succeeds.
6. CI can package browser-specific zip files from `extension/`.
