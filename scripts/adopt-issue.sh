#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/target-config.sh"

if [ $# -ne 1 ] || ! [[ "$1" =~ ^[0-9]+$ ]]; then
    echo "Usage: bash scripts/adopt-issue.sh <issue-number>" >&2
    exit 1
fi

N="$1"
BRANCH="issue-$N-mitigation"

mkdir -p "$FINDINGS_DIR"

if [ ! -d "$CLONE_DIR/.git" ]; then
    echo "Clone missing at $CLONE_DIR - run scripts/prep.sh first" >&2
    exit 1
fi

issue_json="$(gh issue view "$N" --repo "$TARGET" --json number,title,body,labels)"
TITLE="$(printf '%s' "$issue_json" | jq -r '.title')"
BODY="$(printf '%s' "$issue_json" | jq -r '.body')"
LABELS="$(printf '%s' "$issue_json" | jq -r '[.labels[].name] | join(", ")')"

git -C "$CLONE_DIR" checkout "$TARGET_BRANCH"
if git -C "$CLONE_DIR" show-ref --verify --quiet "refs/heads/$BRANCH"; then
    git -C "$CLONE_DIR" branch -D "$BRANCH"
fi
git -C "$CLONE_DIR" switch -c "$BRANCH"

{
    printf '# Issue #%s: %s\n\n' "$N" "$TITLE"
    printf 'Classification: PENDING (run triage agent)\n'
    printf 'Labels: %s\n\n' "$LABELS"
    printf '## Body\n\n'
    printf '%s\n' "$BODY"
} > "$FINDINGS_DIR/issue-$N.md"

echo "Adopted issue #$N"
echo "Branch: $BRANCH (in $CLONE_DIR)"
echo "Findings: $FINDINGS_DIR/issue-$N.md"
echo "Next: run the triage agent, then the mitigator on branch $BRANCH, then the verifier."