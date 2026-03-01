# CBM Product Requirements Document

## 1. Product Goal

Build a macOS menu bar utility to collect GitHub repository links copied as Markdown links from clipboard, persist them into daily markdown notes, and trigger clone command automatically when enabled.

## 2. Target Users

- macOS developers who frequently collect repository references while browsing or reading docs.

## 3. User Stories

1. As a user, I want CBM to run in the menu bar and be easy to enable/disable.
2. As a user, when I copy `[label](https://github.com/owner/repo)` I want it appended into daily notes.
3. As a user, I want CBM to run `git c1 {repo}.git` automatically for accepted links.
4. As a user, I want daily de-duplication so repeated copy does not create duplicate lines or clone actions on the same day.
5. As a user, I want optional multi-link parsing for clipboard content with multiple Markdown links.
6. As a user, I want to open and preview recent daily files from the menu.
7. As a user, I want optional launch at login.
8. As a user, I want Chinese UI by default and English as optional language.
9. As a user, I want command line access to today's markdown path/content.
10. As a user, I want in-app updates via Sparkle 2 (non-App Store).

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

### 4.3 GitHub Repo URL Validation

- Accept only HTTPS GitHub repo URL shape: `https://github.com/owner/repo`.
- Ignore query parameters and hash fragments.
- Normalize accepted URLs to canonical `https://github.com/owner/repo`.
- Optional trailing `/` and `.git` should be tolerated during parsing.

### 4.4 Persistence

- Output base directory configurable.
- Default output directory: `~/Documents/cbm`.
- Daily filename: `links_yyyyMMdd.md`.
- Append format: `* [ ] [label](https://github.com/owner/repo)`.

### 4.5 De-duplication

- Scope: daily only.
- Unique key: normalized repository identity (`owner/repo`).
- For same day, duplicate repo must not:
  - append duplicated markdown line
  - trigger duplicated clone command

### 4.6 Clone Command

- On accepted and non-duplicate repo: run `git c1 {repo}.git`.
- `{repo}` is normalized HTTPS URL without `.git` suffix.

### 4.7 UI and Settings

- Menu items:
  - Enable Monitoring
  - Enable Notifications
  - Allow Multiple Links
  - Launch at Login
  - Output Directory
  - Language (中文 / English)
  - Recent Files (desc by day)
  - About
- Clicking a recent file opens markdown preview window.

### 4.8 CLI

- Provide command line interface to access today's markdown:
  - path output
  - content output

### 4.9 Update Mechanism

- Use Sparkle 2 for non-App Store update flow.

### 4.10 Notifications and Logs

- Support system notification feedback for key events:
  - repo capture summary
  - clone success/failure summary
  - settings action result (where applicable)
- Notifications must be user-toggleable in app settings.
- Write operational logs to daily file in same output directory:
  - filename format: `logs_yyyyMMdd.log`
  - include timestamp and level for each line

## 5. Non-Functional Requirements

- Platform: macOS (Swift + SwiftUI).
- Reliability: clipboard polling must be lightweight and resilient.
- Safety: avoid duplicate clones by daily key tracking.
- Internationalization: Chinese default, English available.

## 6. Out of Scope (Current Iteration)

- Cross-device sync.
- Full-text search across historical files.
- Custom clone command templates (deferred by user decision).

## 7. Acceptance Criteria

1. Enabling monitoring and copying a valid single markdown GitHub repo link appends line and triggers clone once.
2. Copying same repo again on same day triggers neither additional line nor additional clone.
3. Copying non-GitHub or non-repo links does nothing.
4. With multi-link mode disabled, clipboard containing multiple links is ignored.
5. With multi-link mode enabled, all valid repos in clipboard are processed with daily de-dup.
6. CLI can output today's file path and content.
7. Recent files list is descending by date and preview renders markdown.
8. Language can switch between Chinese and English.
9. Sparkle updater can be initialized from app menu and check updates.
