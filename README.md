# Blue Team Box

An AI-assisted defensive devcontainer for triaging, mitigating, and closing security findings on `nmwael/protected-container-asset`.

## Prerequisites

- GitHub Codespaces (or a local devcontainer with Docker)
- `GH_TOKEN` with `issues:read`, `issues:write`, and `contents:write` on `nmwael/protected-container-asset`
- Docker (for Codespaces or local devcontainer builds)

## Quickstart

1. Boot the container (Codespaces or `devcontainer open`).
2. Run:
   ```bash
   bash scripts/run-blue.sh
   ```

## Defensive Loop

```
open issues -> triage (accepted vs rejected)
           -> mitigate (fix in a clone, branch issue-N-mitigation)
           -> verify (asset repo's scripts/verify.sh green; CI gate on push)
           -> close-with-proof (sha + verify pass + scan evidence)
           or reject-with-reason (not planned + rationale)
```

- Every close requires human approval.
- Every push requires `scripts/verify.sh` to pass first.
- The asset repo's `app/vulns/INTENT.md` defines what is in-scope.

## References

- Target repo: `nmwael/protected-container-asset`
- Intent contract: `app/vulns/INTENT.md` in the asset repo
- Close contract: `CONTRIBUTING.md` in the asset repo
- Runbook: `runbook.md`
