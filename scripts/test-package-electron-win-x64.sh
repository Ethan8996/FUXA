#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TARGET_SCRIPT="${REPO_ROOT}/scripts/package-electron-win-x64.sh"

assert_contains() {
    local haystack="$1"
    local needle="$2"

    if [[ "${haystack}" != *"${needle}"* ]]; then
        printf 'Expected output to contain: %s\n' "${needle}" >&2
        exit 1
    fi
}

if [[ ! -x "${TARGET_SCRIPT}" ]]; then
    printf 'Target script is missing or not executable: %s\n' "${TARGET_SCRIPT}" >&2
    exit 1
fi

help_output="$("${TARGET_SCRIPT}" --help)"
assert_contains "${help_output}" "Usage:"
assert_contains "${help_output}" "--dry-run"
assert_contains "${help_output}" "--skip-install"

dry_run_output="$("${TARGET_SCRIPT}" --dry-run)"
assert_contains "${dry_run_output}" "cd server && npm install"
assert_contains "${dry_run_output}" "cd client && npm install"
assert_contains "${dry_run_output}" "npm run build -- --configuration=production"
assert_contains "${dry_run_output}" "cd app/electron && npx electron-builder install-app-deps"
assert_contains "${dry_run_output}" "npx electron-builder --win nsis --x64"

printf 'All assertions passed.\n'
