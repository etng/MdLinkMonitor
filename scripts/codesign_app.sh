#!/usr/bin/env bash
set -euo pipefail

APP_PATH="${1:-}"
if [[ -z "${APP_PATH}" ]]; then
  echo "Usage: scripts/codesign_app.sh <app-path>" >&2
  exit 1
fi

if [[ ! -d "${APP_PATH}" ]]; then
  echo "App bundle not found: ${APP_PATH}" >&2
  exit 1
fi

IDENTITY="${CODESIGN_IDENTITY:--}"
SIGN_ARGS=(--force --deep --sign "${IDENTITY}")

if [[ -n "${CODESIGN_KEYCHAIN:-}" ]]; then
  SIGN_ARGS+=(--keychain "${CODESIGN_KEYCHAIN}")
fi

if [[ "${IDENTITY}" != "-" ]]; then
  if [[ "${CODESIGN_HARDENED_RUNTIME:-1}" != "0" ]]; then
    SIGN_ARGS+=(--options runtime)
  fi

  TIMESTAMP_MODE="${CODESIGN_TIMESTAMP:-1}"
  if [[ "${TIMESTAMP_MODE}" != "0" ]]; then
    SIGN_ARGS+=(--timestamp)
  fi
fi

codesign "${SIGN_ARGS[@]}" "${APP_PATH}"
codesign --verify --deep --strict --verbose=2 "${APP_PATH}"
