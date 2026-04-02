#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

DRY_RUN=0
SKIP_INSTALL=0
SKIP_BUILD=0
SKIP_APP_DEPS=0

usage() {
    cat <<'EOF'
Usage: scripts/package-electron-win-x64.sh [options]

Build the FUXA Electron Windows x64 installer by replaying the current
GitHub Actions workflow locally.

Options:
  --dry-run         Print the commands without executing them.
  --skip-install    Skip all npm install steps.
  --skip-build      Skip the Angular production build.
  --skip-app-deps   Skip electron-builder install-app-deps.
  --help            Show this help message.

Notes:
  - This script stages build inputs into app/electron/server and
    app/electron/client/dist, matching .github/workflows/electron_latest.yml.
  - For reliable results, use Node.js 18 and run on Windows when building the
    Windows NSIS installer.
EOF
}

run_cmd() {
    local cmd="$1"
    if [[ "${DRY_RUN}" -eq 1 ]]; then
        printf '[dry-run] %s\n' "${cmd}"
    else
        printf '>>> %s\n' "${cmd}"
        (cd "${REPO_ROOT}" && eval "${cmd}")
    fi
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=1
            ;;
        --skip-install)
            SKIP_INSTALL=1
            ;;
        --skip-build)
            SKIP_BUILD=1
            ;;
        --skip-app-deps)
            SKIP_APP_DEPS=1
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            printf 'Unknown option: %s\n\n' "$1" >&2
            usage >&2
            exit 1
            ;;
    esac
    shift
done

if [[ "${SKIP_INSTALL}" -eq 0 ]]; then
    run_cmd "cd server && npm install"
    run_cmd "cd client && npm install"
    run_cmd "cd app/electron && npm install"
fi

if [[ "${SKIP_BUILD}" -eq 0 ]]; then
    run_cmd "cd client && npm run build -- --configuration=production"
fi

run_cmd "mkdir -p app/electron/server"
run_cmd "mkdir -p app/electron/client/dist"
run_cmd "cp -r server/. app/electron/server/"
run_cmd "cp -r client/dist/. app/electron/client/dist/"

if [[ "${SKIP_APP_DEPS}" -eq 0 ]]; then
    run_cmd "cd app/electron && npx electron-builder install-app-deps"
fi

run_cmd "cd app/electron && npx electron-builder --win nsis --x64"
