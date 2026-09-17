# OBEY Triage and Severity -- blue-team condensed reference

## Citation note

Every factual claim cites a source inline and is grounded in the approved research-brief URL pool. `[unverified]` marks a named source that has no URL in the pool; its content is taken from the research brief, which remains the authority. Reddit-consensus themes are flagged `(via Reddit search excerpt)` because Reddit blocks direct fetch and the brief carries no Reddit thread URLs.

## When to use

Use when classifying an open issue on the protected container asset as ACCEPT or REJECT, when assigning severity and SLA, or when deciding whether a report is worth an engineer's time. Primary audience: the `triage` agent; `mitigator` and `verifier` also read this book to justify accept/close and to understand severity expectations.

## Primary bias to correct

Jumping straight to "is this a vulnerability?" without first proving it reproduces. Reproduce first, classify second ([unverified] IETF FAST triage draft).

## Repro first

A report is not a vulnerability until a reproduction exists. The rule that dominates triage outcomes: missing repro proof is the strongest correlate of rejection, accounting for roughly a third (33%) of rejected findings ([unverified] IETF FAST triage draft). Community consensus is identical: always reproduce first, never classify from a title alone `(via Reddit search excerpt)`.

Run a six-gate triage check before accepting or rejecting:

| Gate | Question | Fail means |
|------|----------|------------|
| 1 | Request-response proof exists (request in, response out)? | REJECT: nothing to verify |
| 2 | Demonstrated unauthorized access, not just a worrying code path? | REJECT: theoretical |
| 3 | Reproducible in under 2 minutes from the clone? | REJECT: no working repro |
| 4 | Clear impact on confidentiality, integrity, or availability? | REJECT: no security impact |
| 5 | Blast radius bounded and understood (reachable users, data, funds)? | Escalate: unknown scope |
| 6 | Confirmed vulnerability, not a lead or a correlation? | REJECT: unconfirmed |

All six must pass ([unverified] IETF FAST triage draft). A finding that reproduces but whose worst case is cosmetic or already the documented intended behavior is rejected under gate 4/6, not accepted "to be safe" -- but rejecting to avoid work is itself a failure mode; when in doubt classify as ACCEPT and let the mitigator prove the fix.

## Accept vs reject decision tree

REJECT when any of:

- Info-only or hardening suggestion with no demonstrated unauthorized access.
- Out-of-scope for the asset (does not map to `app/vulns/INTENT.md` and is not a legitimately new in-scope vuln).
- Duplicate of an already-open issue.
- Not reproducible (no working repro, request-response proof missing).
- Intended behavior per INTENT.md (benign positive).

ACCEPT when all of:

- Demonstrated unauthorized access or verified integrity/availability impact.
- In-scope root cause (matches INTENT.md or is a legitimately new in-scope vuln).
- Reproducible on the asset clone.
- Real impact, even if severity is low.

An accepted finding is not filed to the backlog and forgotten; it carries an SLA by severity (next section). Close an issue only off the verifier's passing check plus human sign-off, never off a title.

## Severity vs risk (CVSS v4)

Severity is not risk. CVSS v4 separates the vector into Base (intrinsic), Threat (exploitability in the wild), and Environmental (affected environment), and lets you report combined scores as CVSS-B, CVSS-BT, CVSS-BE, or CVSS-BTE. A high-base finding that is un-exploitable in your environment and mitigates your blast radius is far less urgent than a medium-base finding in production with working public exploit code ([unverified] FIRST CVSS v4 calculator, per research brief).

Qualitative bands (CVSS v4 official scale):

| Band | Score range |
|------|-------------|
| None | 0.0 |
| Low | 0.1 - 3.9 |
| Medium | 4.0 - 6.9 |
| High | 7.0 - 8.9 |
| Critical | 9.0 - 10.0 |

Use the FIRST v4 calculator for every accepted finding; do not hand-wave a "feels critical" ([unverified] FIRST CVSS v4 calculator).

## Severity mapping for the four in-scope classes

The asset's four INTENT.md vulnerability classes map to CWEs and severity bands as follows (CWE IDs per research brief, [unverified]):

| Class | CWE | Base band | Note |
|-------|-----|-----------|------|
| Admin authorization bypass | CWE-862 missing authorization | High to Critical | Critical when admin reach changes data |
| Path traversal | CWE-22 | High; Critical | Critical if it yields sensitive file read |
| Hardcoded credentials | CWE-798 | High | Immediate rotate required |
| Server-side template injection | CWE-1336 | Critical | Direct RCE path |

These are floors, not ceilings. Re-visit after computing the BTE score in context ([unverified] FIRST CVSS v4 calculator).

## SLA tiers

SLAs by severity, not gut feel `(via Reddit search excerpt)`:

| Severity | Resolution target |
|----------|-------------------|
| Critical | 7 days |
| High | 30 days |
| Medium | 90 days |
| Low | 360 days |

Map each accepted finding to a tier and record the due date in the triage note.

## Exploitability and reachability supplements

CVSS base alone overstates urgency. Supplement with EPSS (exploit prediction score, per-day probability of exploitation) and KEV (CISA Known Exploited Vulnerabilities catalog); scanners such as Grype already fold EPSS/KEV/VEX metadata into results so triage can surface "known-exploited" instantly ([Lucaberton Trivy vs Grype](https://lucaberton.com/blog/trivy-vs-grype-2026/), [Scaler container security scanning](https://www.scaler.com/blog/what-is-container-security-scanning-trivy-grype-best-practices/)). When EPSS is high or the issue is on KEV, treat as immediate even at Medium base -- and conversely deprioritize base-critical findings with no reachable path in this deployment.

## False positive vs benign positive

Two distinct rejection flavors:

- False positive: the report describes an exploit that does not actually work against this code (e.g., error page shows stack trace but no data leaks).
- Benign positive: the behavior is real but is the documented intended behavior (e.g., an admin ladder offline is reachable only by design).

Both are REJECT, but the rationale must state which one and why. Do not reject a real issue by mislabeling it benign to dodge work.

## AI-slop filtering

Large language model generated reports are choking real-world triage queues -- the community consensus is to automate responsibly, not to ignore the channel `(via Reddit search excerpt)`. Treat an AI-authored report like any other: it still must pass the six gates. Highly templated reports full of plausible-sounding impact statements but no request-response proof usually fail gate 1 or 2; do not spend engineer time "confirming" a report that cannot be reproduced by its own author. Conversely, an AI-assisted report that includes a working repro is as valid as any other -- judge the evidence, not the author.

## OWASP context

Broken access control remains the number one web-app risk (A01) and security misconfiguration number two (A02) in OWASP Top 10 2025 ([unverified] OWASP Top 10 2025, per research brief). These map to two of the four asset classes (admin bypass = A01; exposed debug/default config = A02), which is why they get High floor severity. Container/daemon misconfiguration classes in the asset's deploy path fall under the same A02 umbrella and are asserted by the CIS Docker controls in container-hardening.mini.md ([CIS Docker Benchmark v1.7](https://rayasec.com/wp-content/uploads/CIS-Benchmark/Docker/CIS_Docker_Benchmark_v1.7_PDF.pdf)).

## Triage note and handoff

Per this box's triage agent contract (`team/.opencode/agent/triage.md`), each classification writes `findings/triage-<issue-number>.md` containing: issue number and title, classification (ACCEPT/REJECT), a 2-5 sentence rationale, and whether a repro is present. This is box-runtime procedure, not an external claim, so it is not URL-cited here.

Handoff rules:

- ACCEPT: attach the computed CVSS v4 BTE score, the SLA tier and due date, and the repro steps verbatim so the mitigator can reproduce without re-deriving.
- REJECT: close with an explicit reason and label (false positive, benign positive, duplicate, out-of-scope, not reproducible); "not planned" per the box contract.
- Duplicate: keep the issue carrying the working repro; close the other with a link to it.

## Worked verdicts for the four asset classes

| Report | Repro present | Verdict |
|--------|---------------|---------|
| Admin route returns 200 for an unauthenticated POST and the response demonstrates a control change | Yes, request-response | ACCEPT, High floor per CWE-862 |
| Traversal payload returns the host `/etc/passwd` over HTTP | Yes | ACCEPT, High to Critical per CWE-22 |
| Source tree grep finds `SECRET_KEY=...` committed | Yes (artifact) | ACCEPT, High per CWE-798 |
| `{{7*7}}` renders 49 in the response body | Yes | ACCEPT, Critical per CWE-1336 |
| Report claims SSRF via a debug flag that does not exist in the code | None | REJECT: not reproducible, false positive |
| Admin ladder reachable in dev mode by design per INTENT.md | Yes but intended | REJECT: benign positive |

## Decision rules

- Never accept or reject on title alone; open the repro first.
- Missing request-response proof: REJECT, and say so in the rationale -- this is the single most common rejection cause (~33%).
- Duplicate check against all open issues before every classification.
- New but legitimate in-scope vuln not named in INTENT.md: ACCEPT anyway.
- Severity always carries a computed CVSS v4 score and an SLA due date.
- Rejecting to avoid work is forbidden; uncertainty resolves toward ACCEPT.

## Trigger rules

- Triage workload grows beyond a few reports: batch the evidence check (repro? in scope? duplicate?) instead of per-report hand-waving.
- An accepted finding's SLA is near due with no mitigation branch: escalate to the human, do not silently extend.
- Two reports claim the same root cause: mark the later one DUPLICATE, keep the one with the working repro.
- An AI-generated report arrives without repro: apply the six gates strictly.
- Exploitability picture changes (KEV entry, public PoC): re-score and re-tier the finding.

## Final checklist

- Did I reproduce before classifying?
- Did all six gates pass for ACCEPT listings?
- Is severity a computed CVSS v4 score with an SLA, not a gut feel?
- Is the rationale explicit about repro presence?
- Did I distinguish false positive from benign positive in REJECTs?
- Did I check for duplicates and out-of-scope against INTENT.md?

## Sources

1. IETF FAST triage draft -- [unverified], no URL in research brief pool
2. FIRST CVSS v4 calculator and severity bands -- [unverified], no URL in research brief pool
3. OWASP Top 10 2025 (A01 broken access control, A02 misconfiguration) -- [unverified], no URL in research brief pool
4. EPSS and KEV enrichment in scanners -- https://lucaberton.com/blog/trivy-vs-grype-2026/
5. Scanner EPSS/KEV/VEX metadata -- https://www.scaler.com/blog/what-is-container-security-scanning-trivy-grype-best-practices/
6. CIS Docker Benchmark v1.7 (asserts A02-class controls) -- https://rayasec.com/wp-content/uploads/CIS-Benchmark/Docker/CIS_Docker_Benchmark_v1.7_PDF.pdf
7. OWASP Docker Security Cheat Sheet -- https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html
8. Reddit triage themes (reproduce first; AI-slop automation) -- (via Reddit search excerpt), no thread URL in research brief pool