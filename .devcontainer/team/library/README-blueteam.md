# Blue Team Library

Condensed reference books for the agents of this box. Every claim is cited against an approved research-brief URL pool or marked `[unverified]`; each book ends with a numbered Sources section. No book is exhaustive; the asset repo's `app/vulns/INTENT.md` and `scripts/verify.sh` remain authoritative for accept/close decisions.

## Role to book mapping

| Agent | Book(s) |
|-------|---------|
| `triage` | `blueteam/triage-and-severity.mini.md` |
| `mitigator` | `blueteam/secure-fixes-by-class.mini.md`, `blueteam/container-hardening.mini.md` |
| `verifier` | `blueteam/secure-fixes-by-class.mini.md`, `blueteam/container-hardening.mini.md` |
| all agents | `blueteam/ai-blue-teaming.mini.md` |

Read the books for a role before doing the role's work, following the agent-behavior contract in AGENTS.md.

## Book contents

- `blueteam/triage-and-severity.mini.md` -- repro-first six-gate triage, ACCEPT/REJECT decision tree, CVSS v4 severity vs risk and bands, SLA tiers, EPSS/KEV supplementation, false vs benign positives, and AI-slop report filtering. Map the four in-scope classes (admin CWE-862, traversal CWE-22, creds CWE-798, SSTI CWE-1336) to severity floors.
- `blueteam/secure-fixes-by-class.mini.md` -- root-cause fixes per vulnerability class with framework-level patterns (Flask admin authn/z, `realpath`/`commonpath` containment, environment-injected secrets, template-context rendering), smoke-test expectations per class, PVBench-style fix verification, and CISA/NIST patch-verification steps.
- `blueteam/container-hardening.mini.md` -- CIS Docker Benchmark image-build controls (4.x) and runtime controls (5.x), read-only rootfs and capability dropping, a Flask HEALTHCHECK example, Trivy/Grype scanning with gating, and supply-chain assurance (SBOM, Cosign, SLSA, OpenVEX, digest pinning).
- `blueteam/ai-blue-teaming.mini.md` -- least-privilege tool grants, Progent monotonic confinement, human-in-the-loop gates, the intent gate, guardrail enforcement points, circuit breakers, logging, OWASP LLM 2025 and Agentic 2026, plus guarding this box's own agent devcontainer against lifecycle-hook RCE and token/scope abuse.

## Attribution / Sources

Researched and condensed September 2026 from two approved research briefs:

- BLUETEAM RESEARCH BRIEF (triage, fixes-by-class, container hardening, verification; source names inline, URLs marked `[unverified]` where the brief carried none).
- CONTAINER-AND-AI RESEARCH BRIEF, source file `wip/CONTAINER-AND-AI-RESEARCH-BRIEF.md` in the feature repo -- 55 attributed URLs; this library pulls from its A2 (Docker defense), A3 (devcontainer pitfalls), B2 (AI blue teaming), and B3 (OWASP LLM/Agentic) sections.

Reddit-consensus themes are flagged `(via Reddit search excerpt)` per the citation policy; Reddit blocks direct fetch, so those claims carry the theme name and the brief holds no thread URLs. URL sets are per-book in each book's Sources section. Do not add URLs outside the two briefs; mark ungroundable claims `[unverified]` instead.

## Notes

- No emojis; ASCII only in these files.
- Keep books conditional and imperative; when in doubt, the asset repo's verification scripts and INTENT.md win.

## Installation

`scripts/prep.sh` copies this tree into `$WORKSPACE/library/` at box startup (the block guarded by `[ -d "$TEAM_DIR/library" ]`); nothing here is applied unless the box runs prep. The copy is idempotent (`set -euo pipefail` preserved). Keep books out of the shipped image and inside `library/` only.

## Conventions

- Every book opens with a Citation note that defines `[unverified]` and the `(via Reddit search excerpt)` flag, then a When to use and a Primary bias to correct.
- Books close with a numbered `## Sources` section listing exactly the URLs referenced inline from the approved pool; no URL outside the two briefs may be added later.
- Tables compress repeated content (severity bands, control-to-action, guardrail points); keep rows short and imperative.
- A change to any book must update the role-to-book mapping above and re-run the verification checks in the box runbook (ASCII, no placeholders, URL count).