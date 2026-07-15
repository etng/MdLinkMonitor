# AGENTS

## User Preferences

- If the user only says "handle issues" (or equivalent) without naming a tool, detect whether the repository `origin` is hosted on `github.com`; if yes, default to using `gh` for issue triage and handling.
- "Handle issues" includes implementing the fix/feature, releasing a version (default patch unless explicitly specified otherwise), posting a processing comment, and closing the issue after completion.
- Issue processing comments should always include the released version number (and preferably the release date) so readers can quickly identify when the fix became available.
- Issue comments must be sent as proper Markdown with real newlines; never post literal `\n` escape sequences.
- When processing GitHub issues via `gh`, if comments from the repository owner (derived from `origin` remote owner) mention bumping a version (e.g. `minor` / `patch`) without an explicit forced choice for this task, default to a `patch` version bump.

## Issue Lifecycle Defaults

- Use standard triage labels consistently: `needs-info`, `cannot-reproduce`, `wontfix` (or `not-planned`), `duplicate`, `released` (or `done`).
- If key reproduction context is missing, request only minimal required info (app version, repro steps, expected vs actual), apply `needs-info`, and wait up to 14 days.
- If no reply arrives within 14 days for `needs-info`, close the issue and keep the label for traceability.
- For non-reproducible reports after reasonable attempts, apply `cannot-reproduce`, document attempted environment/steps, and close.
- For already implemented/released work, comment with `fixed in vX.Y.Z` (and date when available), apply `released`/`done`, then close.
- For out-of-scope or declined work, apply `wontfix`/`not-planned`, explain rationale briefly, then close.
- For duplicates, apply `duplicate`, link the canonical issue, and close immediately.
- Closed issues should not be re-processed repeatedly; only reopen when new evidence arrives (new repro steps/logs, or still reproducible on latest release).
- High-risk exceptions (security/data-loss/corruption) should not follow normal timeout auto-close flow; escalate and keep active until explicitly triaged.
