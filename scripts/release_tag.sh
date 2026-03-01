#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/release_tag.sh <semver>
  VERSION=<semver> scripts/release_tag.sh

Example:
  scripts/release_tag.sh 0.2.0
  make release-tag VERSION=0.2.0
USAGE
}

VERSION="${1:-${VERSION:-}}"
if [[ -z "${VERSION}" ]]; then
  usage
  exit 1
fi

if [[ ! "${VERSION}" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-([0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*))?(\+([0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*))?$ ]]; then
  echo "Invalid semver: ${VERSION}" >&2
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Working tree is not clean. Commit or stash changes before release tagging." >&2
  exit 1
fi

PLIST_PATH="packaging/Info.plist"
if [[ ! -f "${PLIST_PATH}" ]]; then
  echo "Missing plist: ${PLIST_PATH}" >&2
  exit 1
fi

TAG="v${VERSION}"
PLIST_BACKUP="$(mktemp)"
DID_COMMIT=0

restore_plist_if_needed() {
  if [[ "${DID_COMMIT}" -eq 0 && -f "${PLIST_BACKUP}" ]]; then
    cp "${PLIST_BACKUP}" "${PLIST_PATH}"
  fi
}

cleanup() {
  rm -f "${PLIST_BACKUP}"
}

on_error() {
  restore_plist_if_needed
  cleanup
}

trap on_error ERR INT TERM

if git rev-parse -q --verify "refs/tags/${TAG}" >/dev/null; then
  echo "Local tag already exists: ${TAG}" >&2
  exit 1
fi

if git ls-remote --exit-code --tags origin "refs/tags/${TAG}" >/dev/null 2>&1; then
  echo "Remote tag already exists on origin: ${TAG}" >&2
  exit 1
fi

CURRENT_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${PLIST_PATH}" 2>/dev/null || true)"
cp "${PLIST_PATH}" "${PLIST_BACKUP}"

if [[ -z "${CURRENT_VERSION}" ]]; then
  /usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string ${VERSION}" "${PLIST_PATH}"
elif [[ "${CURRENT_VERSION}" != "${VERSION}" ]]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "${PLIST_PATH}"
fi

if ! git diff --quiet -- "${PLIST_PATH}"; then
  git add "${PLIST_PATH}"
  git commit -m "chore(release): 🔧 bump version to ${VERSION}"
  DID_COMMIT=1
fi

git tag -a "${TAG}" -m "release: ${TAG}"
git push origin HEAD
git push origin "${TAG}"

trap - ERR INT TERM
cleanup

echo "Release tag pushed: ${TAG}"
