#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/target-config.sh"

WORKSPACE="${WORKSPACE:-$(pwd)}"
TEAM_DIR="$HERE/../.devcontainer/team"

echo "== Blue team prep =="

if [ -f "$TEAM_DIR/AGENTS.md" ]; then
    cp -f "$TEAM_DIR/AGENTS.md" "$WORKSPACE/AGENTS.md"
    echo "OK AGENTS.md overwritten with blue-team contract"
else
    echo "WARNING $TEAM_DIR/AGENTS.md not found - leaving workspace AGENTS.md untouched" >&2
fi

mkdir -p "$WORKSPACE/.opencode/agent"
count=0
for f in "$TEAM_DIR/.opencode/agent"/*.md; do
    if [ -f "$f" ]; then
        cp -f "$f" "$WORKSPACE/.opencode/agent/"
        count=$((count + 1))
    fi
done
echo "OK copied $count blue-team agent role file(s) to $WORKSPACE/.opencode/agent"

if [ -d "$TEAM_DIR/library" ]; then
    mkdir -p "$WORKSPACE/library"
    rm -rf "$WORKSPACE/library/library"
    cp -rf "$TEAM_DIR/library/." "$WORKSPACE/library/"
    echo "OK blue-team library books installed to $WORKSPACE/library"
fi

mkdir -p "$FINDINGS_DIR"
echo "OK findings dir ready at $FINDINGS_DIR"

if [ ! -d "$CLONE_DIR/.git" ]; then
    echo "Cloning https://github.com/${TARGET}.git -> $CLONE_DIR"
    git clone --depth 1 "https://github.com/${TARGET}.git" "$CLONE_DIR"
else
    git -C "$CLONE_DIR" fetch --prune
    git -C "$CLONE_DIR" checkout "$TARGET_BRANCH"
    git -C "$CLONE_DIR" pull
fi
echo "OK target clone ready at $CLONE_DIR (branch $TARGET_BRANCH)"

if ! gh issue list --repo "$TARGET" --state open >/dev/null 2>&1; then
    echo "WARNING cannot list issues on $TARGET - check GH_TOKEN and gh auth status" >&2
fi
echo "OK issue access verified for $TARGET"

echo "Prep complete."