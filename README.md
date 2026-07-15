# MdMonitor

中文说明: [README.zh-CN.md](./README.zh-CN.md)

MdMonitor is a macOS menu bar app for collecting Markdown links from your clipboard.

When monitoring is enabled, copied links in `[label](link)` format are processed automatically. It can also process a single plain URL from allowlisted domains by fetching the page title and summary first.

1. Append to today's markdown file.
2. Detect Git repositories by configured domains.
3. Run your clone command template for recognized repositories.

Default clone template: `git clone {repo}.git`
Default clone directory: `~/Documents/cbm/repos`

## What It Does

- Menu bar app with on/off monitoring.
- Daily de-duplication for markdown append and clone.
- Supports repository domains like `github.com`, `gitlab.com`, and custom hosts.
- Supports allowlisted plain-URL domains that should be fetched for page metadata before writing.
- Supports custom clone command template with `{repo}` placeholder.
- Supports configurable clone working directory.
- Detects WeChat image attachments from `mmbiz.qpic.cn`, stores them in a persistent attachment library, and keeps them out of daily markdown links.
- Tracks attachment MD5, can match external files named `{md5}_MD.{ext}` in a configured resource directory, and writes attachment blacklist entries to `blacklist.yaml`.
- Optional auto-merge for app windows (`Window -> Merge All Windows`) with bundleId targeting (one per line).
- Keeps daily logs next to daily markdown files.
- Main window includes markdown preview/source split view, calendar jump, attachment library, and live log panel.
- Built-in Sparkle 2 update channel (non-App Store).

## Default Output

- Output directory: `~/Documents/cbm`
- Daily markdown: `links_yyyyMMdd.md`
- Daily log: `logs_yyyyMMdd.log`
- Attachments: `attachments/<sha1>.<ext>` with sidecar metadata
- Attachment blacklist: `blacklist.yaml`
- Markdown line format: `* [ ] [label](link)`
- Metadata-enriched line format: `* [ ] [label](link) - summary`

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
3. For special pages that are hard to convert in-browser, add the host to the plain-URL metadata allowlist and copy the raw page URL instead.
4. Open the main window from menu:
   - `Today`
   - recent dates
   - settings/help/updates
5. Configure:
   - output directory
   - repository domains
   - plain-URL metadata allowlist
   - attachment resource directory
   - clone command template
   - clone directory
   - auto-merge windows (optional bundleIds, one per line)
   - language / notifications / launch-at-login
   - On first use, MdMonitor reads Obsidian's active or most recently opened vault for the attachment and Daily directories. You can re-detect it or choose both directories manually in Settings.
6. In preview, you can:
   - pause/resume monitoring
   - switch between rendered / split / source views
   - sort the current markdown file by domain on demand
   - open the attachment library
   - inspect MD5 / external resource matches / blacklist-assisted deletion for attachments

## Capture Feedback

After the app recognizes processable content, the menu bar icon briefly changes color so you can tell what happened without opening logs or the main window.

- Green: recognized as a repository and clone was triggered.
- Blue: recognized and saved, but no clone was needed for this capture.
- Orange: recognized, but skipped because it was already captured today or the attachment already existed.
- Taupe: recognized, but blocked by a rule such as the attachment blacklist.
- Red: recognized, but a follow-up action failed. Check today's log for details.

## Troubleshooting

- Clipboard not captured:
  - ensure monitoring is enabled
  - if multi-link mode is off, copy exactly one markdown link
  - for plain URLs, add the domain to the metadata allowlist first
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
