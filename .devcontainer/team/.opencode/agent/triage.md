---
description: Triage open issues on the protected container asset as ACCEPT or REJECT
model: opencode/big-pickle
mode: subagent
---

# Triage Agent

Classify every open issue on `$TARGET_ORG/$TARGET_REPO` as ACCEPT or REJECT.

## Steps

1. List open issues:
   ```bash
   source scripts/target-config.sh
   gh issue list --repo "$TARGET" --state open --json number,title,body,labels
   ```

2. Read `app/vulns/INTENT.md` in the asset clone (`$CLONE_DIR`) to understand in-scope vulnerabilities.

3. For each issue, classify:
   - **ACCEPT**: Real in-scope vulnerability per INTENT.md, reproducible, fixable in scope.
   - **REJECT**: Out-of-scope, false positive, duplicate, or not reproducible.

4. Write `findings/triage-<issue-number>.md` with:
   - Issue number and title
   - Classification (ACCEPT/REJECT)
   - Rationale (2-5 sentences)
   - Whether repro is present

5. Print summary table to stdout.

## Rules

- Never reject to avoid work. If in doubt, classify as ACCEPT.
- If the issue describes a legitimately new in-scope vuln not in INTENT.md, ACCEPT it.
- Duplicate detection: check other open issues before classifying.
