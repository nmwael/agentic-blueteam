# Blue Team Runbook

The human-turn playbook for triaging and resolving red-team findings.

## 1. Wake the Box

Boot the devcontainer. Codespaces injects `GH_TOKEN` automatically. For local use, export `GH_TOKEN` before starting.

## 2. Start the Loop

```bash
bash scripts/run-blue.sh
```

This clones (or refreshes) the target repo, lists open issues, and guides you through triage.

## 3. Review Triage Decisions

For each open issue, the triage agent classifies it as ACCEPT or REJECT:

- **ACCEPT**: Real in-scope vulnerability per `app/vulns/INTENT.md`, reproducible, fixable within scope.
- **REJECT**: Out-of-scope, false positive, duplicate, or not reproducible.

Review the triage output in `findings/triage-<issue>.md`. You may override the classification.

## 4. For Accepted Issues

1. Adopt the issue:
   ```bash
   bash scripts/adopt-issue.sh <issue-number>
   ```
2. Switch to the clone and work on branch `issue-<N>-mitigation`.
3. Implement the minimal fix (one issue per branch, only relevant files).
4. Run verification:
   ```bash
   bash scripts/verify.sh
   ```
5. Push the branch to the asset repo.
6. Human approves the push and the close:
   ```bash
   bash scripts/close-issue.sh <issue> close <sha>
   ```

## 5. For Rejected Issues

```bash
bash scripts/close-issue.sh <issue> reject
```

Provide a clear rationale. The script closes with `--reason "not planned"`.

## Mandatory Rules

- **Verify before close**: `scripts/verify.sh` must pass before any close.
- **HITL approval**: Human approves every push and every close.
- **Min-diff discipline**: One issue per branch. Only relevant files. No unrelated refactors.
- **INTENT changes**: If a fix changes an INTENT contract (endpoint, flag), update `app/vulns/INTENT.md` in the same PR.
- **Scope**: Asset repo only. No changes to other repos or infrastructure.
