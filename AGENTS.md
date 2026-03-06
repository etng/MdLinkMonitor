# AGENTS

## User Preferences

- If the user only says "handle issues" (or equivalent) without naming a tool, detect whether the repository `origin` is hosted on `github.com`; if yes, default to using `gh` for issue triage and handling.
- "Handle issues" includes implementing the fix/feature, releasing a version (default patch unless explicitly specified otherwise), posting a processing comment, and closing the issue after completion.
- Issue processing comments should always include the released version number (and preferably the release date) so readers can quickly identify when the fix became available.
- Issue comments must be sent as proper Markdown with real newlines; never post literal `\n` escape sequences.
- When processing GitHub issues via `gh`, if comments from the repository owner (derived from `origin` remote owner) mention bumping a version (e.g. `minor` / `patch`) without an explicit forced choice for this task, default to a `patch` version bump.
