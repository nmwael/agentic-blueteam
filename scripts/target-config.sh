#!/usr/bin/env bash
set -euo pipefail

BLUE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

TARGET_ORG="nmwael"
TARGET_REPO="protected-container-asset"
TARGET_BRANCH="main"
TARGET="${TARGET_ORG}/${TARGET_REPO}"
CLONE_DIR="${BLUE_DIR}/asset-clone"
FINDINGS_DIR="${BLUE_DIR}/findings"

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    echo "source this file, don't run it" >&2
    exit 0
fi

return 0