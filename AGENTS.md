# AGENTS

## User Preferences

- If the user only says "handle issues" (or equivalent) without naming a tool, detect whether the repository `origin` is hosted on `github.com`; if yes, default to using `gh` for issue triage and handling.
- When processing GitHub issues via `gh`, if comments from the repository owner (derived from `origin` remote owner) mention bumping a version (e.g. `minor` / `patch`) without an explicit forced choice for this task, default to a `patch` version bump.
