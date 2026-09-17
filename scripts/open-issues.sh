#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/target-config.sh"

if ! gh issue list --repo "$TARGET" --state open --json number,title,labels,createdAt --jq 'sort_by(.number)[] | "#\(.number) \(.title) [\([.labels[].name] | join(","))]"'; then
    echo "No open issues (or gh unavailable)." >&2
    exit 0
fi