#!/usr/bin/env bash
set -euo pipefail

app_path="${1:-build/MdMonitorDev.app}"
identity="${DEV_CODESIGN_IDENTITY:-Goi Local Signing}"
keychain_file="${DEV_SIGNING_KEYCHAIN:-${HOME}/Library/Keychains/goi-signing.keychain-db}"
keychain_password="${DEV_SIGNING_KEYCHAIN_PASSWORD:-}"

if [[ ! -d "${app_path}" ]]; then
  echo "App bundle not found: ${app_path}" >&2
  exit 1
fi

if [[ -n "${keychain_password}" ]]; then
  security unlock-keychain -p "${keychain_password}" "${keychain_file}"
fi

read_requirement() {
  codesign -d -r- "$1" 2>&1 | sed -n 's/^designated => //p'
}

read_cdhash() {
  codesign -dv --verbose=4 "$1" 2>&1 | sed -n 's/^CDHash=//p'
}

original_requirement="$(read_requirement "${app_path}")"
original_cdhash="$(read_cdhash "${app_path}")"

probe_root="$(mktemp -d)"
trap 'rm -rf "${probe_root}"' EXIT
probe_app="${probe_root}/MdMonitorDev.app"
ditto "${app_path}" "${probe_app}"

printf 'signature stability probe\n' > "${probe_app}/Contents/Resources/signature-stability-probe.txt"
CODESIGN_IDENTITY="${identity}" \
  CODESIGN_KEYCHAIN="${keychain_file}" \
  CODESIGN_HARDENED_RUNTIME=0 \
  CODESIGN_TIMESTAMP=0 \
  bash scripts/codesign_app.sh "${probe_app}" >/dev/null

probe_requirement="$(read_requirement "${probe_app}")"
probe_cdhash="$(read_cdhash "${probe_app}")"

if [[ "${original_cdhash}" == "${probe_cdhash}" ]]; then
  echo "Expected the probe bundle CDHash to change." >&2
  exit 1
fi

if [[ "${original_requirement}" != "${probe_requirement}" ]]; then
  echo "Designated requirement changed after bundle contents changed." >&2
  echo "before: ${original_requirement}" >&2
  echo "after:  ${probe_requirement}" >&2
  exit 1
fi

echo "Bundle contents changed: ${original_cdhash} -> ${probe_cdhash}"
echo "Designated requirement stayed stable: ${original_requirement}"
