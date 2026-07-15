# MdM Product Requirements Document

中文版: [prd.zh-CN.md](./prd.zh-CN.md)

## 1. Product Goal

Build a macOS menu bar utility to collect Markdown links copied from clipboard into daily notes, and automatically trigger clone for links recognized as Git repositories under configured domains.

## 2. Target Users

- macOS developers who frequently collect repository references while browsing or reading docs.

## 3. User Stories

1. As a user, I want MdM to run in the menu bar and be easy to enable/disable.
2. As a user, when I copy `[label](link)` I want it appended into daily notes.
3. As a user, I want MdM to run my configured clone command template automatically for recognized repository links.
4. As a user, I want daily de-duplication so repeated copy does not create duplicate lines or duplicate clone actions on the same day.
5. As a user, I want optional multi-link parsing for clipboard content with multiple Markdown links.
6. As a user, I want to configure repository domains (for example `github.com`, `gitlab.com`).
7. As a user, I want a configurable default clone directory.
8. As a user, I want a dedicated Settings window instead of placing all settings in the menu.
9. As a user, I want to open and preview recent daily files from the menu.
10. As a user, in today's preview I want a collapsible live log panel for troubleshooting.
11. As a user, I want optional launch at login.
12. As a user, I want Chinese UI by default and English as optional language.
13. As a user, I want command line access to today's markdown path/content.
14. As a user, I want in-app updates via Sparkle 2 (non-App Store).

## 4. Functional Requirements

### 4.1 Monitoring

- App lives in macOS menu bar.
- Monitoring only runs when explicitly enabled.
- Disabled state means no clipboard handling and no command execution.

### 4.2 Clipboard Parsing

- Input: plain text from clipboard.
- Primary pattern: Markdown link `[label](link)`.
- Default mode accepts only exactly one markdown link in clipboard content.
- If `Allow Multiple Links` is enabled, parse and process all markdown links in content.

### 4.3 Repository URL Recognition

- Repository recognition uses a configurable domain allowlist.
- URL must be HTTPS and match repository path shape: `/owner/repo`.
- Ignore query parameters and hash fragments.
- Normalize accepted repository URLs to canonical `https://host/owner/repo`.
- Optional trailing `/` and `.git` should be tolerated during parsing.

### 4.4 Persistence

- Output base directory configurable.
- Default output directory: `~/Documents/cbm`.
- Daily filename: `links_yyyyMMdd.md`.
- Append format: `* [ ] [label](link)`.
- All detected markdown links are appended when not deduplicated, regardless of repository recognition.

### 4.5 De-duplication

- Scope: daily only.
- For repository links, unique key: normalized repository identity (`host/owner/repo`).
- For non-repository links, unique key: normalized URL (query/hash removed).
- For same day, duplicate links must not:
  - append duplicated markdown line
  - trigger duplicated clone command

### 4.6 Clone Command

- On recognized and non-duplicate repository links: run configured clone command template.
- Template must include `{repo}` placeholder.
- `{repo}` is normalized HTTPS URL without `.git` suffix.
- Default template: `git clone {repo}.git`.
- Clone directory is configurable; default is `~/Documents/cbm/repos`.
- Non-repository links must be appended but never cloned.

### 4.7 UI and Settings

- Menu items include:
  - Enable Monitoring
  - Open Settings
  - Open Today
  - Recent Files (direct list of latest 7 days)
  - Check for Updates
  - About
- Settings window includes:
  - Enable Notifications
  - Allow Multiple Links
  - Launch at Login
  - Output Directory
  - Clone Directory
  - Language (中文 / English)
  - Repository Domains editor + apply action
  - Clone command template editor + apply action
- Clicking a recent file opens markdown preview window.
- Preview window has left sidebar for historical file browsing and right panel markdown rendering.
- Today preview includes a default-collapsed live log panel that auto-refreshes from `logs_yyyyMMdd.log`.

### 4.8 CLI

- Provide command line interface to access today's markdown:
  - path output
  - content output

### 4.9 Update Mechanism

- Use Sparkle 2 for non-App Store update flow.
- Update startup/check failures are silent in UI and written to daily logs.

### 4.10 Notifications and Logs

- Support system notification feedback for key events:
  - capture summary
  - clone success/failure summary
  - settings action result (where applicable)
- Notifications must be user-toggleable in settings.
- Write operational logs to daily file in same output directory:
  - filename format: `logs_yyyyMMdd.log`
  - include timestamp and level for each line
  - include explicit markdown append logs
  - include debug event traces in debug builds

## 5. Non-Functional Requirements

- Platform: macOS (Swift + SwiftUI).
- Reliability: clipboard polling must be lightweight and resilient.
- Safety: avoid duplicate clones by daily key tracking.
- Internationalization: Chinese default, English available.

## 6. Out of Scope (Current Iteration)

- Cross-device sync.
- Full-text search across historical files.

## 7. Acceptance Criteria

1. Enabling monitoring and copying one valid markdown link appends one line once per day.
2. Copying a recognized repository link on configured domains appends line and triggers clone once per day.
3. Copying same recognized repository again on same day triggers neither additional line nor additional clone.
4. Copying non-repository markdown link appends line but does not clone.
5. With multi-link mode disabled, clipboard containing multiple links is ignored.
6. With multi-link mode enabled, all markdown links are processed with daily dedup and only recognized repositories are cloned.
7. CLI can output today's file path and content.
8. Menu shows direct recent 7-day files; preview renders markdown with left sidebar browsing.
9. Today preview shows default-collapsed live log panel and refreshes log content automatically.
10. Language can switch between Chinese and English.
11. Sparkle updater can be initialized from app menu and check updates silently on failure.
