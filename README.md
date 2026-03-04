# MdMonitor

中文说明: [README.zh-CN.md](./README.zh-CN.md)

MdMonitor is a macOS menu bar app for collecting Markdown links from your clipboard.

When monitoring is enabled, copied links in `[label](link)` format are processed automatically:

1. Append to today's markdown file.
2. Detect Git repositories by configured domains.
3. Run your clone command template for recognized repositories.

Default clone template: `git clone {repo}.git`
Default clone directory: `~/Documents/cbm/repos`

## What It Does

- Menu bar app with on/off monitoring.
- Daily de-duplication for markdown append and clone.
- Supports repository domains like `github.com`, `gitlab.com`, and custom hosts.
- Supports custom clone command template with `{repo}` placeholder.
- Supports configurable clone working directory.
- Keeps daily logs next to daily markdown files.
- Main window includes markdown preview, calendar jump, and live log panel.
- Built-in Sparkle 2 update channel (non-App Store).

## Default Output

- Output directory: `~/Documents/cbm`
- Daily markdown: `links_yyyyMMdd.md`
- Daily log: `logs_yyyyMMdd.log`
- Markdown line format: `* [ ] [label](link)`

## Install

1. Download `MdMonitor.dmg` from Releases.
2. Open the DMG.
3. Drag `MdMonitor.app` to `Applications`.
4. Launch from `Applications`.

If Gatekeeper warns that the app cannot be verified, right-click `MdMonitor.app` -> `Open` -> confirm `Open`.

## Command Line (Optional)

- Open **Settings -> System -> Install mdm Command**.
- The app installs `mdm` to `/usr/local/bin/mdm`.
- If permission is required, macOS will ask for administrator authorization.
- After successful installation, Settings shows `mdm installed` and hides the install button.
- Verify in Terminal:
  ```bash
  mdm help
  ```
- Common commands:
  ```bash
  mdm today --path   # print today's links markdown path
  mdm today --print  # print today's markdown content
  mdm status         # print current settings snapshot
  mdm help           # print command help
  ```

## Use

1. Click the menu bar icon and keep `Enable Monitoring` on.
2. Copy markdown links while browsing.
3. Open the main window from menu:
   - `Today`
   - recent dates
   - settings/help/updates
4. Configure:
   - output directory
   - repository domains
   - clone command template
   - clone directory
   - language / notifications / launch-at-login

## Troubleshooting

- Clipboard not captured:
  - ensure monitoring is enabled
  - if multi-link mode is off, copy exactly one markdown link
  - check daily log file in output directory
- A link is appended but not cloned:
  - it did not match repository domain/path rules
- Spotlight opens old version:
  - keep only one install location (`/Applications` preferred)
  - run `make refresh-launch-services APP_PATH=/Applications/MdMonitor.app` if needed

## License and Acknowledgements

- License: [MIT](./LICENSE)
- Third-party acknowledgements: [docs/acknowledgements.md](./docs/acknowledgements.md)

## For Contributors

Development and release workflow are documented in [docs/contribution.md](./docs/contribution.md).
