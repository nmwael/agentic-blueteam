#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/target-config.sh"

usage() {
    cat <<'EOF'
Usage: bash scripts/close-issue.sh <issue> close|reject [sha]

  close   requires a commit sha; comments MITIGATED then closes with --label accepted
  reject  closes with --reason "not planned" and a rationale, --label rejected

A verdict file at findings/issue-<N>.vcl (VERDICT=..., REASON=...) is read if present.
EOF
}

confirm() {
    if [ ! -t 0 ]; then
        echo "No interactive tty - aborting. Run interactively to close issues." >&2
        return 1
    fi
    local prompt="$1" ans
    printf '%s [y/N] ' "$prompt"
    read -r ans
    case "${ans,,}" in
        y|yes) return 0 ;;
        *) return 1 ;;
    esac
}

ensure_label() {
    local label="$1"
    if ! gh label view "$label" --repo "$TARGET" >/dev/null 2>&1; then
        gh label create "$label" --repo "$TARGET" >/dev/null 2>&1 || true
    fi
}

[ $# -ge 2 ] || { usage; exit 1; }

ISSUE="$1"
ACTION="$2"
SHA="${3:-}"

case "$ACTION" in
    close|reject) ;;
    *) echo "action must be 'close' or 'reject'" >&2; usage; exit 1 ;;
esac

[[ "$ISSUE" =~ ^[0-9]+$ ]] || { echo "issue must be numeric" >&2; usage; exit 1; }

if [ "$ACTION" = close ] && [ -z "$SHA" ]; then
    echo "close requires a commit sha: bash scripts/close-issue.sh $ISSUE close <sha>" >&2
    exit 2
fi

VCL="$FINDINGS_DIR/issue-$ISSUE.vcl"
VERDICT=""
VERDICT_REASON=""
if [ -f "$VCL" ]; then
    VERDICT="$(sed -n 's/^[[:space:]]*VERDICT=[[:space:]]*//p' "$VCL" | tr -d '\r' | head -n 1)"
    VERDICT_REASON="$(sed -n 's/^[[:space:]]*REASON=[[:space:]]*//p' "$VCL" | tr -d '\r' | head -n 1)"
    echo "Verdict file: $VCL -> VERDICT=$VERDICT"
    if [ -n "$VERDICT" ] && [ "$VERDICT" != "$ACTION" ]; then
        echo "verdict says $VERDICT but action is $ACTION - aborting" >&2
        exit 3
    fi
fi

if [ "$ACTION" = close ]; then
    MSG="mitigated @ $SHA - verify.sh PASS, CI green"
    [ -n "$VERDICT_REASON" ] && MSG="$MSG. $VERDICT_REASON"
    if ! confirm "Close issue #$ISSUE as mitigated? ($MSG)"; then
        echo "aborted by operator"
        exit 1
    fi
    ensure_label accepted
    if ! gh issue close "$ISSUE" --repo "$TARGET" --comment "$MSG" --label accepted; then
        echo "gh failed to close issue #$ISSUE" >&2
        exit 1
    fi
else
    REASON="$VERDICT_REASON"
    if [ -z "$REASON" ]; then
        if [ ! -t 0 ]; then
            echo "no tty and no REASON in $VCL - cannot reject without a rationale" >&2
            exit 1
        fi
        printf 'Rejection reason: '
        read -r REASON
    fi
    [ -n "$REASON" ] || { echo "reason cannot be empty" >&2; exit 1; }
    MSG="rejected: $REASON"
    if ! confirm "Reject issue #$ISSUE (not planned)? $MSG"; then
        echo "aborted by operator"
        exit 1
    fi
    ensure_label rejected
    if ! gh issue close "$ISSUE" --repo "$TARGET" --reason "not planned" --comment "$MSG" --label rejected; then
        echo "gh failed to close issue #$ISSUE" >&2
        exit 1
    fi
fi

echo "Closed issue #$ISSUE ($ACTION)."