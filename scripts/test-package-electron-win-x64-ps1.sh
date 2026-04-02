#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TARGET_SCRIPT="${REPO_ROOT}/scripts/package-electron-win-x64.ps1"

assert_file_contains() {
    local file="$1"
    local needle="$2"

    if ! grep -Fq -- "${needle}" "${file}"; then
        printf 'Expected %s to contain: %s\n' "${file}" "${needle}" >&2
        exit 1
    fi
}

if [[ ! -f "${TARGET_SCRIPT}" ]]; then
    printf 'Target script is missing: %s\n' "${TARGET_SCRIPT}" >&2
    exit 1
fi

assert_file_contains "${TARGET_SCRIPT}" "param("
assert_file_contains "${TARGET_SCRIPT}" '[switch]$DryRun'
assert_file_contains "${TARGET_SCRIPT}" '[switch]$SkipInstall'
assert_file_contains "${TARGET_SCRIPT}" "npm install"
assert_file_contains "${TARGET_SCRIPT}" "npm run build -- --configuration=production"
assert_file_contains "${TARGET_SCRIPT}" "npx electron-builder install-app-deps"
assert_file_contains "${TARGET_SCRIPT}" "npx electron-builder --win nsis --x64"

printf 'All assertions passed.\n'
