# MdMonitor

Chinese version: [README.zh-CN.md](./README.zh-CN.md)

MdMonitor is a macOS menu bar app written in Swift.

When monitoring is enabled, it watches clipboard text and handles Markdown links in the format `[label](link)`. MdMonitor:

1. Appends deduplicated markdown task lines into the daily file.
2. Detects Git repository links by configured domains (for example `github.com`, `gitlab.com`).
3. Normalizes matched repository URLs (ignores query/hash, trims trailing slash and `.git`), then runs `git c1 {repo}.git`.

## Key Features

- Menu bar app with enable/disable monitoring switch.
- Optional system notifications with in-app toggle.
- Optional Dock icon visibility toggle (enabled by default).
- Optional launch at login.
- Chinese by default with English localization support and runtime language switch.
- Daily file output under configurable directory (default: `~/Documents/cbm`).
- Daily log output under same directory (`logs_yyyyMMdd.log`).
- Daily de-duplication for both markdown append and clone.
- Non-repository markdown links are still appended (without clone).
- Git repository recognition supports configurable domains (for example `github.com`, `gitlab.com`).
- Optional multi-link processing for clipboard text containing multiple markdown links.
- Recent 7-day files shown directly in menu.
- Dedicated Settings window for configuration.
- Preview window with left-side history file browser.
- Today preview includes a default-collapsed live log panel for troubleshooting.
- CLI command to get today's markdown path/content.
- Sparkle 2 based in-app update channel (non-App Store distribution).

## Default Output

- Directory: `~/Documents/cbm`
- File name: `links_yyyyMMdd.md`
- Line format: `* [ ] [label](https://example.com/path)`
- Log file: `logs_yyyyMMdd.log`

## Development

- Swift: 6+
- Platform: macOS
- Build: `swift build`
- Test: `swift test`
- Run CLI: `swift run cbm help`
- Run menu bar app: `swift run MdMonitor`

## Packaging & Distribution

### Build a `.app` bundle (recommended with Xcode)

1. Open `Package.swift` in Xcode.
2. Select product `MdMonitor` and target `My Mac`.
3. Use `Product -> Archive`.
4. In Organizer, choose `Distribute App -> Copy App` (or export signed build).
5. You will get `MdMonitor.app` for local install/testing.

### Build a `.dmg` from an existing `.app`

Use CLI packaging directly:

```bash
make app         # build dist/MdMonitor.app
make dmg         # build dist/MdMonitor.dmg
make install     # install to /Applications (or INSTALL_DIR override)
make install-local
```

If `hdiutil` is unavailable in your environment, `make dmg` falls back to `dist/MdMonitor.zip`.
`make app` embeds `Sparkle.framework` into `Contents/Frameworks` automatically.
`make dmg` now includes an `Applications` shortcut in the mounted image, so users can drag `MdMonitor.app` directly for install.
`make install` now auto-moves a duplicate `~/Applications/MdMonitor.app` to a timestamped backup to avoid Spotlight launching an old copy (`REMOVE_DUPLICATE_COPY=0` to disable).

If you already have an exported app, you can still create dmg manually. Assume `MdMonitor.app` is at `dist/MdMonitor.app`:

```bash
mkdir -p dist/dmg
cp -R dist/MdMonitor.app dist/dmg/
hdiutil create \
  -volname "MdMonitor" \
  -srcfolder dist/dmg \
  -ov \
  -format UDZO \
  dist/MdMonitor.dmg
```

### User installation

1. Open `MdMonitor.dmg`.
2. Drag `MdMonitor.app` into `Applications`.
3. Launch from `Applications` (first launch may require Gatekeeper confirmation).
4. If you see "`Apple cannot verify...`", this build is currently not notarized with a paid Apple Developer account.
5. For manual trust on your own Mac: right click `MdMonitor.app` -> `Open` -> confirm `Open` again.

### Release notes

- Sparkle feed URL is `https://github.com/etng/MdLinkMonitor/releases/latest/download/appcast.xml`.
- Tag push `v<semver>` triggers `.github/workflows/release.yml` to build artifacts and upload `appcast.xml` into the release.
- Use `make release-tag VERSION=x.y.z` to sync plist version, commit, tag, and push.
- Configure repository secrets before first Sparkle release:
  - `SPARKLE_PRIVATE_KEY`: base64 Ed25519 private seed (32-byte decoded)
  - `SPARKLE_PUBLIC_KEY`: base64 Ed25519 public key (`SUPublicEDKey` value in `Info.plist`)
- For public distribution outside personal machines, add code-signing + notarization in your release pipeline.
- Current project status: no paid Apple Developer account yet, so builds are unsigned/non-notarized for Gatekeeper trust.

## CLI

- `cbm today --path`: print today's markdown file path.
- `cbm today --print`: print today's markdown file content.
- `cbm status`: print current settings snapshot.

## Architecture

- `Sources/CBMCore`: parser, URL normalization, daily store, dedup, clipboard pipeline, settings, clone executor.
- `Sources/CBMMenuBar`: menu bar UI, preferences, preview window, launch-at-login, Sparkle updater entry.
- `Sources/cbm`: CLI entry.
- `Tests/CBMCoreTests`: unit tests for core logic.

## Notes

- Clone command is fixed to `git c1 {repo}.git` in this iteration.
- Daily dedup means duplicates are blocked only within the same day.
- Sparkle update checks require proper app signing and appcast setup in distribution.
- Update startup failures are handled silently and only written to daily logs.
- In debug/dev runs, `Launch at Login` may fail due app signing/bundle constraints.
- When started via `swift run MdMonitor`, system notifications are disabled intentionally; use `.app` launch for Notification Center integration.

## Troubleshooting

- If clipboard capture appears not working:
  - Ensure `Enable Monitoring` is ON in menu bar app.
  - Copy exactly one markdown link unless `Allow Multiple Links` is ON.
  - Check daily log file: `~/Documents/cbm/logs_yyyyMMdd.log` (or your configured output directory).
  - On successful append, logs include `Appended markdown entry: ...`.
  - In debug builds, UI event traces are written with `[event]` prefix.
- If a link is not recognized as a repository domain/path:
  - It is still appended to markdown.
  - Clone is skipped by design.
- If menu action beeps but no popup:
  - Update to latest code in this repo; menu actions now execute after menu dismiss.
- If Spotlight launches an unexpected old MdMonitor version:
  - Check both `/Applications/MdMonitor.app` and `~/Applications/MdMonitor.app`.
  - Keep only one active install location (prefer `/Applications`).
  - Run `make refresh-launch-services APP_PATH=/Applications/MdMonitor.app`.

## Dev Diagnostics

- Verbose UI event logging is controlled by `Diagnostics.verboseEventLogging`.
- File: `Sources/CBMMenuBar/Diagnostics.swift`
- Default behavior:
  - `DEBUG`: enabled
  - non-`DEBUG`: disabled

## Current Status

See:

- PRD: `docs/prd.md`
- Task board: `docs/todo.md`
