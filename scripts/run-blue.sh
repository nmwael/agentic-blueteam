#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/target-config.sh"

usage() {
    echo "Usage: bash scripts/run-blue.sh [--all | <issue-number>]" >&2
    echo "Runs the defensive round: prep clone -> list issues -> adopt -> triage -> mitigate -> verify -> close/reject" >&2
}

confirm() {
    if [ ! -t 0 ]; then
        echo "No interactive tty - skipping prompt." >&2
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

open_numbers() {
    gh issue list --repo "$TARGET" --state open --json number --jq '.[].number' 2>/dev/null | sort -n
}

adopt_and_guide() {
    local n="$1"
    "${HERE}/adopt-issue.sh" "$n"
    echo
    echo "Next steps for issue #$n:"
    echo "  1. Run the triage agent (writes findings/triage-$n.md, ACCEPT or REJECT)"
    echo "  2. Run the mitigator agent in $CLONE_DIR on branch issue-$n-mitigation (verify.sh must pass)"
    echo "  3. Run the verifier agent (writes findings/issue-$n.vcl)"
    echo "  4. bash scripts/close-issue.sh $n close <sha>  |  bash scripts/close-issue.sh $n reject"
}

echo "== Blue team defensive box =="
"${HERE}/prep.sh"
echo
echo "== Open issues on $TARGET =="
"${HERE}/open-issues.sh"

mode="${1:-}"

if [ -n "$mode" ] && [ "$mode" != "--all" ] && ! [[ "$mode" =~ ^[0-9]+$ ]]; then
    echo "Unknown argument: $mode" >&2
    usage
    exit 1
fi

case "$mode" in
    "")
        if [ ! -t 0 ]; then
            echo "No tty and no issue selected - pass an issue number or --all." >&2
            exit 0
        fi
        echo "Enter an issue number to adopt (one per turn), --all to sweep, or q to quit."
        while true; do
            printf 'Adopt which issue? '
            read -r choice || break
            case "${choice,,}" in
                q) break ;;
                --all)
                    while read -r n; do
                        [ -n "$n" ] || continue
                        if confirm "Adopt issue #$n?"; then
                            adopt_and_guide "$n"
                        else
                            echo "skipped issue #$n"
                        fi
                    done < <(open_numbers)
                    ;;
                ''|*[!0-9]*) echo "invalid choice: $choice" ;;
                *) adopt_and_guide "$choice" ;;
            esac
        done
        ;;
    --all)
        if ! open_numbers | grep -q .; then
            echo "No open issues to adopt."
            exit 0
        fi
        while read -r n; do
            [ -n "$n" ] || continue
            if confirm "Adopt issue #$n?"; then
                adopt_and_guide "$n"
            else
                echo "skipped issue #$n"
            fi
        done < <(open_numbers)
        ;;
    *)
        adopt_and_guide "$mode"
        ;;
esac

echo "Round complete. Human approval gate: close/reject only via close-issue.sh."