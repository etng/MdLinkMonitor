# Contribution Guide

This document is for contributors and maintainers.

## Development Setup

- Swift: 6.2+
- Platform: macOS

Commands:

```bash
swift build
swift test
swift run MdMonitor
swift run cbm help
```

## Packaging

```bash
make app
make dmg
make install
make install-local
```

## Versioning

- Project uses SemVer.
- Release tags use `v<major>.<minor>.<patch>`.
- Keep `packaging/Info.plist` version fields aligned with the tag.

## Release Flow

1. Ensure `master` is clean.
2. Run:
   ```bash
   make release-tag VERSION=x.y.z
   ```
3. CI workflow `.github/workflows/release.yml` builds artifacts and publishes the release automatically.

## Sparkle Secrets

Set repository secrets before release:

- `SPARKLE_PRIVATE_KEY`: base64 Ed25519 private seed (decoded 32 bytes)
- `SPARKLE_PUBLIC_KEY`: base64 Ed25519 public key (must match `SUPublicEDKey` in `packaging/Info.plist`)

## Debug Diagnostics

- Verbose event logging switch: `Sources/CBMMenuBar/Diagnostics.swift`
- Debug logs are written to daily log files next to markdown output.
