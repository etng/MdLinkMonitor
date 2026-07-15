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
swift run mdm help
```

## Packaging

```bash
make app
make dmg
make install
make install-local
```

Local packaging defaults to ad-hoc signing. Release artifacts from GitHub Actions should use a stable Developer ID signature.

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

## Apple Signing Secrets

Signed release artifacts are optional. If these secrets are omitted, CI falls back to the previous ad-hoc signing flow and still publishes the release.

- `APPLE_DEVELOPER_ID_CERT_P12_BASE64`: base64-encoded `.p12` file containing the `Developer ID Application` certificate
- `APPLE_DEVELOPER_ID_CERT_PASSWORD`: password for the `.p12` certificate export
- `APPLE_NOTARY_KEY_ID`: App Store Connect API key id for `notarytool`
- `APPLE_NOTARY_ISSUER_ID`: App Store Connect issuer id for `notarytool`
- `APPLE_NOTARY_PRIVATE_KEY_BASE64`: base64-encoded `.p8` private key for `notarytool`

If only the notarization secrets are omitted, CI still signs with Developer ID but skips notarization.

## Debug Diagnostics

- Verbose event logging switch: `Sources/MdMMenuBar/Diagnostics.swift`
- Debug logs are written to daily log files next to markdown output.
