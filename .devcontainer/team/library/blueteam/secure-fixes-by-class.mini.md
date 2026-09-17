# OBEY Secure Fixes by Class -- blue-team condensed reference

## Citation note

Every factual claim cites a source inline and is grounded in the approved research-brief URL pool. `[unverified]` marks a named source (standard, control ID, tool, or CVE) that has no URL in the pool; its content is taken from the research brief, which remains the authority. Reddit-consensus themes are flagged `(via Reddit search excerpt)`.

## When to use

Use while implementing and verifying a fix for any accepted finding against the four protected asset classes: admin authorization bypass, path traversal, hardcoded credentials, and server-side template injection. Primary audience: the `mitigator` agent writing the fix and the `verifier` agent checking it before close.

## Primary bias to correct

Fixing the symptom instead of the root cause, and "silencing" a failing check rather than making the vulnerability impossible. A fix is complete only when the original repro fails and a regression test proves the fix.

## Fix workflow discipline

- One issue per mitigation branch (`issue-<N>-mitigation`); only files relevant to that vulnerability change. No unrelated refactors or style churn ([unverified] asset repo CONTRIBUTING flow; community practice `(via Reddit search excerpt)`).
- Keep the diff minimal and document the root cause in the PR body; a reviewer must be able to see why this specific change removes the specific weakness `(via Reddit search excerpt)`.
- Never suppress or exclude a security check from config without fixing the underlying cause -- "suppress, don't exclude" means tune a false-positive rule, never disable the rule that would have caught future regressions `(via Reddit search excerpt)`.
- Add a regression test that fails before the fix and passes after `(via Reddit search excerpt)`.
- If a fix changes an INTENT contract (endpoint, flag, behavior), update `app/vulns/INTENT.md` in the same commit.

## Why regression tests matter (PVBench evidence)

Rigorous patch verification shows that roughly 42% of patches judged "correct" by reviewers fail when actually run against the problem they claim to fix -- under original-PoC replay plus broader functional testing. Treat every fix as unproven until the original proof of concept is re-run against the patched code and neutralized. A fix must (1) neutralize the original PoC, (2) add a regression test, and (3) not regress adjacent functionality ([unverified] PVBench, per research brief).

## Class A -- Admin authorization bypass (CWE-862)

Root cause: the admin route trusts the caller's claim instead of enforcing authorization server-side on every request ([unverified] OWASP ASVS V4.1.1, per research brief).

Minimum fix:

- Enforce access control server-side on every protected request; deny by default. Never gate on client-supplied state ([unverified] OWASP ASVS V4.1.1/4.1.3, per research brief).
- Decorate admin handlers with the framework auth check (Flask: `@login_required`) plus an explicit role check; both, in that order ([unverified] OWASP ASVS V4.1.5, per research brief).
- Return 403 (not 404 or 302-to-login) for API routes when the caller is authenticated but not authorized, so the denial is explicit and loggable ([unverified] OWASP ASVS V4.1.3, per research brief).
- Log and alert on access-control failures; silent 403s are a blind spot for detection ([unverified] OWASP A01:2025, per research brief).
- Admin accounts: require MFA (V4.3.1), expire sessions on logout with session invalidation (V3.3.1), and issue a fresh token on authentication (V3.2.1) ([unverified] OWASP ASVS, per research brief).

Smoke test: unauthenticated request to admin route returns 401/redirect; authenticated non-admin user returns 403. Verify.sh in the asset repo is the gate.

## Class B -- Path traversal (CWE-22)

Root cause: user input is concatenated into a filesystem path, and the resulting path escapes the intended directory ([unverified] OWASP ASVS V12, per research brief).

Minimum fix:

- Resolve then contain: `os.path.realpath()` the candidate path and assert the resolved path stays under the base directory using `os.path.commonpath()` -- a containment check. Do not rely on `startswith()` or bare `os.path.abspath()`; prefix tricks (`/../../etc/passwd` normalizing to `/etc/passwd`) defeat naive prefix checks ([unverified] CWE-22 mitigations, per research brief).
- Or take only the basename: `os.path.basename(user_input)` / `werkzeug.utils.secure_filename()`, which strips separators and dot-dot segments ([unverified] Flask/Werkzeug secure filename, per research brief).
- Reject absolute paths and any input containing `..` outright before any filesystem call.
- Run the reading process against a read-only filesystem rooted at the jail directory so even a bypass can only read the intended tree (see container-hardening.mini.md CIS read-only rootfs).
- Python 3.9+: prefer `pathlib.Path.is_relative_to()` for the containment assertion; it is the express, collision-free check ([unverified] Python docs, per research brief).

Smoke test: traversal payloads (`../../../../etc/passwd`, encoded variants `%2e%2e%2f`) return a safe response (404 or jail-scoped data), never root filesystem content.

## Class C -- Hardcoded credentials (CWE-798)

Root cause: secrets committed to source or baked into the image in a way that survives history ([unverified] CWE-798, per research brief).

Minimum fix:

- Move secrets out of source into environment variables (12-factor), injected at runtime, never via `ENV` or `COPY .env` in the image ([OWASP Docker Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html), [Sentry Docker security review](https://github.com/getsentry/skills/blob/main/skills/security-review/infrastructure/docker.md)).
- Store at rest in a secrets manager rather than a repo: Vault, AWS Secrets Manager, or SOPS-encrypted files -- values decrypted at deploy time, not committed ([unverified] per research brief).
- Add secret detection to pre-commit and CI: gitleaks, git-secrets, or truffleHog as a local hook plus a scanner in CI with build failure on hits ([unverified] per research brief). Trivy can also scan images/secrets/repos in the same pipeline ([Scaler](https://www.scaler.com/blog/what-is-container-security-scanning-trivy-grype-best-practices/), [Lucaberton](https://lucaberton.com/blog/trivy-vs-grype-2026/)).
- Rotate exposed secrets immediately: any secret visible in `git log`, issue text, or a previous image layer is compromised even if deleted later -- layers are immutable ([Sentry Docker security review](https://github.com/getsentry/skills/blob/main/skills/security-review/infrastructure/docker.md), [CodeReviewLab](https://www.codereviewlab.com/learning/container-security)).
- Add a startup check that refuses to boot on default/placeholder credentials and fails the healthcheck loudly. "Refuse to boot on default creds" turns a findable vulnerability into a hard failure ([unverified] per research brief).

Smoke test: with real credentials removed, the credential check fails cleanly; with placeholder credentials, the app refuses to start and the healthcheck reports failing.

## Class D -- Server-side template injection (CWE-1336)

Root cause: user-controlled content is passed through the template engine and evaluated as template code ([unverified] CWE-1336, per research brief).

Minimum fix:

- Never call `render_template_string(user_input)`. The correct pattern is to pass untrusted content as template context data and render a fixed template: `render_template("render.html", content=user_input)` ([unverified] Flask SSTI guidance, per research brief).
- Keep autoescaping on; unescaped `{{ }}` and `{% %}` in data stay inert when the text is rendered as context, not evaluated.
- A sandboxed template environment is defense-in-depth only, not a boundary: sandbox escapes exist and are re-found regularly (current example: CVE-2026-11104 attribute-filter bypass). Sandbox must never be your only control ([unverified] per research brief).
- Add a triage/detection probe: submit `{{7*7}}`; an evaluated engine returns 49. `{{config}}` as a probe exposes framework configuration when the engine evaluates. These probes are the detection tooling; the fix must make them render literally ([unverified] SSTI detection probes, per research brief; maps to OWASP WSTG template-injection test and Snyk/SecureLayer7 guidance, [unverified] URLs).

Smoke test: the string `{{7*7}}` appears literally, un-evaluated, in the rendered response.

## Fix verification and incident handling

A fix is verified only through the asset repo's `scripts/verify.sh` plus the class smoke tests above, then independent re-attempt of the original repro by the verifier. Verification borrows the NIST incident-response lifecycle -- prepare, detect, respond, recover, and feed lessons learned back into control tuning ([unverified] NIST SP 800-61r3, per research brief).

CISA-style patch verification steps ([unverified] CISA patch-management guidance, per research brief):

1. Test the fix in an environment that simulates production (the asset clone on the mitigation branch).
2. Confirm the original problem is gone (original repro no longer yields the flag).
3. Smoke-test adjacent behavior for functional regression.
4. Ensure rollback is possible and recorded.
5. Record the change in configuration management with the issue reference.

Deploy via ring rollout (small canary ring first, expand after verification) rather than a single big-bang release ([unverified] per research brief).

## Cross-class fix matrix

One table per class, consolidating the requirements above: root cause, minimal fix, smoke test, regression test.

| Class | Root cause | Minimal fix | Smoke test | Regression test |
|-------|------------|-------------|------------|-----------------|
| Admin bypass (CWE-862) | Route trusts caller claim | Server-side authn/z every request, deny by default, `@login_required` + role check, 403 on API, log and alert failures | Unauthenticated 401/redirect; non-admin 403 | Role matrix test: guest, user, admin against every admin route |
| Path traversal (CWE-22) | User input concatenated into path | `realpath` + `commonpath` containment or `secure_filename` basename; reject absolute and `..`; read-only jail; `is_relative_to()` on 3.9+ | `../../../../etc/passwd` and encoded variants return safe response | Payload suite covering `..`, encoded slashes, absolute paths, null bytes |
| Hardcoded creds (CWE-798) | Secret in source or image layer | Env-injected secrets; vault/SOPS at rest; pre-commit and CI secret scan; rotate exposed; refuse boot on default creds | Placeholder creds fail startup; healthcheck reports failing | Commit hook scanner test plus startup-refusal test on default values |
| SSTI (CWE-1336) | User content evaluated as template | Render fixed template with content as context; autoescape on; sandbox is defense-in-depth only | `{{7*7}}` renders literally, un-evaluated | Probe suite `{{7*7}}`, `{{config}}`, `{% ... %}` payloads |

## Verifier replay protocol

Independent verification before close replays, does not re-derive:

- Re-run the original issue repro against the mitigation branch and assert the vulnerable behavior is gone.
- Run the class smoke test for the fixed class and the cross-class matrix row above.
- Run `scripts/verify.sh` from a clean checkout; then check CI status for the mitigation branch.
- Write the verdict (`findings/issue-<N>.vcl` with VERDICT=close or VERDICT=reject and the reason), per the box's verifier contract (`team/.opencode/agent/verifier.md`). The verifier modifies no code.

## Decision rules

- Fix the root cause: the control that makes the class impossible, not the specific observed input.
- Add a regression test with every fix; no test, no merge.
- Keep the diff minimal and INTENT-contract changes in the same PR.
- Never silence a security check to make CI green; tune the rule and keep the control.
- Every fix ends with the class smoke test and `scripts/verify.sh` passing.

## Trigger rules

- The original PoC still succeeds after the patch: the fix is incomplete; go back to root cause.
- The check was disabled instead of fixed: restore it and fix the rule.
- A second finding in the same class appears: the fix was input-specific; generalize the control and add coverage.
- Auth bypass reported: re-run the full admin surface, not just the reported route.

## Final checklist

- Root cause fixed, not the symptom?
- Regression test added and run?
- Original PoC replayed and neutralized?
- Adjacent behavior smoke-tested (no regression)?
- Secrets rotated if exposure touched any history/image layer?
- INTENT.md kept in sync if behavior changed?
- `scripts/verify.sh` green on the mitigation branch?

## Sources

1. OWASP Docker Security Cheat Sheet (no image-layer secrets) -- https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html
2. Sentry Docker security review (env secret leakage) -- https://github.com/getsentry/skills/blob/main/skills/security-review/infrastructure/docker.md
3. CodeReviewLab container security guide (layer immutability) -- https://www.codereviewlab.com/learning/container-security
4. Scaler container security scanning (Trivy secret scans) -- https://www.scaler.com/blog/what-is-container-security-scanning-trivy-grype-best-practices/
5. Lucaberton Trivy vs Grype (scanner coverage) -- https://lucaberton.com/blog/trivy-vs-grype-2026/
6. Safeguard container image hardening checklist -- https://safeguard.sh/resources/blog/container-image-hardening-checklist
7. OWASP ASVS (V4.1.1/4.1.3/4.1.5, V4.3.1, V3.3.1, V3.2.1, V12) -- [unverified], no URL in research brief pool
8. OWASP A01:2025 broken access control -- [unverified], no URL in research brief pool
9. CWE-22 / CWE-798 / CWE-1336 and CWE-862 mitigations -- [unverified], no URL in research brief pool
10. PVBench patch-verification evidence (~42% of "correct" patches fail) -- [unverified], no URL in research brief pool
11. NIST SP 800-61r3 incident response lifecycle -- [unverified], no URL in research brief pool
12. CISA patch-management verification steps -- [unverified], no URL in research brief pool
13. SSTI detection probes and WSTG/Snyk/SecureLayer7 guidance; CVE-2026-11104 sandbox bypass -- [unverified], no URL in research brief pool
14. Werkzeug secure_filename -- [unverified], no URL in research brief pool
15. Secrets managers (Vault/AWS SM/SOPS), secret scanners (gitleaks/git-secrets/truffleHog) -- [unverified], no URL in research brief pool
16. Reddit fix-hygiene themes (minimal diff, root-cause documentation, regression tests, suppress-don't-exclude) -- (via Reddit search excerpt), no thread URL in research brief pool