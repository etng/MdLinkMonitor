#!/usr/bin/env bash
set -euo pipefail

APP_PATH="${1:-}"
VOLUME_NAME="${2:-}"
OUTPUT_PATH="${3:-}"
DMG_MAKER_COMMIT="${4:-}"

if [[ -z "${APP_PATH}" || -z "${VOLUME_NAME}" || -z "${OUTPUT_PATH}" || -z "${DMG_MAKER_COMMIT}" ]]; then
  echo "Usage: scripts/create_dmg.sh <app-path> <volume-name> <output-path> <dmg-maker-commit>" >&2
  exit 1
fi

if [[ ! -d "${APP_PATH}" ]]; then
  echo "App bundle not found: ${APP_PATH}" >&2
  exit 1
fi

REPO_URL="${DMG_MAKER_REPO:-https://github.com/saihgupr/DMGMaker}"
WORK_ROOT="${DMG_MAKER_WORK_ROOT:-$(pwd)/build/dmg-maker}"
PACKAGE_DIR="${WORK_ROOT}/src/DMGMaker"

mkdir -p "${WORK_ROOT}/src"

if [[ ! -d "${PACKAGE_DIR}/.git" ]]; then
  rm -rf "${PACKAGE_DIR}"
  git clone --depth 1 "${REPO_URL}" "${PACKAGE_DIR}"
fi

git -C "${PACKAGE_DIR}" fetch --depth 1 origin "${DMG_MAKER_COMMIT}" >/dev/null 2>&1 || \
  git -C "${PACKAGE_DIR}" fetch origin "${DMG_MAKER_COMMIT}" >/dev/null 2>&1
git -C "${PACKAGE_DIR}" checkout --force "${DMG_MAKER_COMMIT}" >/dev/null

swift build --disable-sandbox --package-path "${PACKAGE_DIR}" -c release --product "DMG Maker" >/dev/null
BIN_DIR="$(swift build --disable-sandbox --package-path "${PACKAGE_DIR}" -c release --show-bin-path)"
DMG_MAKER_BIN="${BIN_DIR}/DMG Maker"

if [[ ! -x "${DMG_MAKER_BIN}" ]]; then
  echo "DMGMaker binary not found at ${DMG_MAKER_BIN}" >&2
  exit 1
fi

APP_DIR="$(cd "$(dirname "${APP_PATH}")" && pwd)"
GENERATED_DMG="${APP_DIR}/${VOLUME_NAME}.dmg"

rm -f "${GENERATED_DMG}" "${OUTPUT_PATH}"
"${DMG_MAKER_BIN}" --app "${APP_PATH}" --name "${VOLUME_NAME}"

if [[ ! -f "${GENERATED_DMG}" ]]; then
  echo "DMGMaker did not produce ${GENERATED_DMG}" >&2
  exit 1
fi

if [[ "${GENERATED_DMG}" != "${OUTPUT_PATH}" ]]; then
  mkdir -p "$(dirname "${OUTPUT_PATH}")"
  mv -f "${GENERATED_DMG}" "${OUTPUT_PATH}"
fi

echo "Generated ${OUTPUT_PATH}"
