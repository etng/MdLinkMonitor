# Clipboard Repo Monitor (CBM)

CBM is a macOS menu bar app written in Swift.

When monitoring is enabled, it watches clipboard text and handles Markdown links in the format `[label](link)`. If the link is a GitHub repository URL (`https://github.com/owner/repo`), CBM:

1. Normalizes the repository URL (ignores query/hash, trims trailing slash and `.git`).
2. Appends a task line to the daily markdown file.
3. Runs `git c1 {repo}.git` to clone the repository.

## Key Features

- Menu bar app with enable/disable monitoring switch.
- Optional system notifications with in-app toggle.
- Optional launch at login.
- Chinese by default with English localization support and runtime language switch.
- Daily file output under configurable directory (default: `~/Documents/cbm`).
- Daily log output under same directory (`logs_yyyyMMdd.log`).
- Daily de-duplication for both markdown append and clone.
- Optional multi-link processing for clipboard text containing multiple markdown links.
- Recent files list (sorted by date desc) and markdown preview window.
- CLI command to get today's markdown path/content.
- Sparkle 2 based in-app update channel (non-App Store distribution).

## Default Output

- Directory: `~/Documents/cbm`
- File name: `links_yyyyMMdd.md`
- Line format: `* [ ] [label](https://github.com/owner/repo)`
- Log file: `logs_yyyyMMdd.log`

## Development

- Swift: 6+
- Platform: macOS
- Build: `swift build`
- Test: `swift test`
- Run CLI: `swift run cbm help`
- Run menu bar app: `swift run CBMMenuBar`

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
- In debug/dev runs, `Launch at Login` may fail due app signing/bundle constraints.
- When started via `swift run CBMMenuBar`, system notifications are disabled intentionally; use `.app` launch for Notification Center integration.

## Current Status

See:

- PRD: `docs/prd.md`
- Task board: `docs/todo.md`
