# Blue Team Agent Contract

This box defends `nmwael/protected-container-asset` against red-team findings. All agents operate under HITL: human approves every push and every close.

## ACCOUNTABILITY

Mitigation is only real when the asset repo's `scripts/verify.sh` passes and CI is green on the push. Verification-before-close is MANDATORY. No issue may be closed without a passing verify run and human sign-off.

## Decision Framework

### ACCEPT

A finding is ACCEPT when all of:
- It is a real, in-scope vulnerability per `app/vulns/INTENT.md` (or a legitimately new in-scope vuln).
- The red team provided a reproducible reproduction.
- The fix is achievable within the asset repo's scope.

Workflow: adopt the issue, fix on branch `issue-<N>-mitigation`, verify, push, close with proof.

### REJECT

A finding is REJECT when any of:
- Out-of-scope for the asset.
- False positive (not actually exploitable as described).
- Duplicate of an existing issue.
- Not reproducible (no working repro provided).

Workflow: close with `--reason "not planned"` and a clear rationale. Must not reject to avoid work.

## Min-Diff Discipline

- One issue per branch.
- Only modify files relevant to the fix.
- No unrelated refactors, cleanups, or style changes.
- Keep diffs as small as possible.

## Cross-Team

- Read `app/vulns/INTENT.md` before triaging any issue.
- If a fix changes an INTENT contract (endpoint, flag, behavior), update `app/vulns/INTENT.md` in the same PR.

## Tooling requests

The box's tooling is fixed by the devcontainer. Agents must NEVER install a
missing command on their own (apt/pip/npm/go install, downloading binaries) —
such installs usually fail or vanish on rebuild. Report needed tooling (what +
why) to the human for an HITL-gated devcontainer change; do not improvise this
round.

## Verification Protocol

1. Run `scripts/verify.sh` in the asset clone before pushing.
2. Push only if verify passes.
3. After push, check CI status: `gh run list --repo "$TARGET"`.
4. Close only after verify pass + CI green + human approval.

## Agents

| Agent | Role |
|-------|------|
| `triage` | Classify open issues as ACCEPT or REJECT |
| `mitigator` | Implement fixes for accepted issues |
| `verifier` | Independent secondary verification before close |
