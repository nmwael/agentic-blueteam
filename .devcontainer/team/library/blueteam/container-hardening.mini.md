# OBEY Container Hardening -- blue-team condensed reference

## Citation note

Every factual claim cites a source inline and is grounded in the approved research-brief URL pool. `[unverified]` marks a named source or control that has no URL in the pool; its content is taken from the research brief, which remains the authority. CIS control numbers refer to the CIS Docker Benchmark structure.

## When to use

Use when auditing or hardening the protected Flask container image and its runtime config, when writing the Dockerfile/compose change for a container-hardening finding, or when checking the container half of a mitigation before close. Primary audience: `mitigator` and `verifier`.

## Primary bias to correct

Treating the Dockerfile as the whole story. Defense is layered: image-build controls (CIS section 4 image-level controls), runtime controls (CIS section 5), vulnerability scanning, and supply-chain assurance. A clean CVE scan does not mean a hardened runtime.

## Image-build controls (CIS Docker Benchmark image section)

| Control | Rule | Why |
|---------|------|-----|
| 4.1 | Non-root `USER` near end of Dockerfile | Single most impactful CIS fix; runs app as unprivileged user so a compromise does not inherit root ([Safeguard.sh CIS guide](https://safeguard.sh/resources/blog/docker-cis-benchmark-what-it-checks-and-how-to-pass-it)) |
| 4.2 | Build from a trusted base image (registry, tag, digest) | Unknown bases are an unknown supply chain ([Safeguard CIS guide](https://safeguard.sh/resources/blog/docker-cis-benchmark-what-it-checks-and-how-to-pass-it), [NIST SP 800-190](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-190.pdf)) |
| 4.3 | Install only needed packages | Smaller attack surface and smaller image ([Safeguard hardening checklist](https://safeguard.sh/resources/blog/container-image-hardening-checklist)) |
| 4.4 | Scan images, then rebuild on fix | Old layers keep old CVEs; rebuild is the remediation step ([Safeguard hardening checklist](https://safeguard.sh/resources/blog/container-image-hardening-checklist)) |
| 4.6 | Add a HEALTHCHECK | Liveness/probe reveals readiness and fails closed on app death ([CIS Docker Benchmark v1.7](https://rayasec.com/wp-content/uploads/CIS-Benchmark/Docker/CIS_Docker_Benchmark_v1.7_PDF.pdf)) |
| 4.9 | Use COPY, not ADD | ADD auto-extracts archives and pulls from remote URLs; COPY is predictable ([OWASP Docker Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)) |
| 4.10 | No secrets in the image | `ENV`, `.env` files, build args persist in immutable layers, readable via `docker history`/`inspect` ([OWASP Docker Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html), [Sentry Docker review](https://github.com/getsentry/skills/blob/main/skills/security-review/infrastructure/docker.md)) |
| 4.11 | Pin base-image versions | Mutable tags (`latest`) drift; pin to a version/digest ([Safeguard CIS guide](https://safeguard.sh/resources/blog/docker-cis-benchmark-what-it-checks-and-how-to-pass-it)) |

Use a multi-stage build: builder stage compiles, final stage copies only runtime artifacts, so compilers, source, and build-time secrets never reach the shipped image ([Safeguard hardening checklist](https://safeguard.sh/resources/blog/container-image-hardening-checklist)). `pip-audit` or a uv-managed lockfile keeps Python dependencies matched to advisories at build time; `.dockerignore` keeps `findings/`, notebooks, and local secrets out of the build context ([unverified] per research brief).

## Runtime controls (CIS Docker Benchmark runtime section)

| Control | Rule | Why |
|---------|------|-----|
| 5.4 | `--cap-drop ALL` at minimum | Default grants `SETUID`, `KILL`, `SYS_CHROOT` few apps need; a compromised app inherits them ([OWASP Docker Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html), [Dash0](https://www.dash0.com/faq/how-to-secure-running-docker-containers)) |
| 5.5 | Add back only needed caps, e.g. `--cap-add NET_BIND_SERVICE`; never `--privileged` | Capability reduction is first line of defense against kernel-callback and privesc bugs ([CIS Docker Benchmark v1.7](https://rayasec.com/wp-content/uploads/CIS-Benchmark/Docker/CIS_Docker_Benchmark_v1.7_PDF.pdf)) |
| 5.11 | Limit memory and CPU: `--memory`, `--cpus` | Without limits one compromised container starves neighbors ([Opslog](https://opslog.dev/blog/docker-security-best-practices)) |
| 5.12 | Limit pids: `--pids-limit` | Required to stop fork bombs inside the container ([Opslog](https://opslog.dev/blog/docker-security-best-practices), [Dash0](https://www.dash0.com/faq/how-to-secure-running-docker-containers)) |
| 5.13 | Read-only root filesystem; tmpfs writable dirs (`/tmp`, uploads) | Blocks dropping tools, writing scripts, persistence ([OWASP Docker Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html), [Opslog](https://opslog.dev/blog/docker-security-best-practices)) |
| 5.22 | Do not disable the default seccomp profile | Seccomp drops dangerous syscalls for the whole container ([CIS Docker Benchmark v1.7](https://rayasec.com/wp-content/uploads/CIS-Benchmark/Docker/CIS_Docker_Benchmark_v1.7_PDF.pdf)) |
| 5.25 | `--security-opt=no-new-privileges:true` | Blocks privesc via setuid/setgid binaries inside the container ([dev-sec CIS Docker controls](https://github.com/dev-sec/cis-docker-benchmark/blob/master/controls/container_runtime.rb)) |
| 5.32 | Never mount `/var/run/docker.sock` | Socket access equals root on the host; attackers use it within minutes to run privileged containers ([TheCodeForge](https://thecodeforge.io/devops/docker-security-best-practices/), [Dash0](https://www.dash0.com/faq/how-to-secure-running-docker-containers)) |

Do not run the container with the default root identity and a writable filesystem at the same time; that combination cancels image hardening ([Opslog](https://opslog.dev/blog/docker-security-best-practices)). Where deeper syscall discipline is needed, dynamic system-call filtering that learns the app baseline reduces runtime attack surface further; this is active research, not a required gate ([Optimus](https://link.springer.com/article/10.1186/s13677-024-00639-3), [ConLock](https://conand.me/publications/elkhairi-conlock-2025.pdf)).

## HEALTHCHECK example (Flask)

A container liveness check that exercises the app without adding a Python web client to the image, hitting localhost only ([CIS 4.6](https://rayasec.com/wp-content/uploads/CIS-Benchmark/Docker/CIS_Docker_Benchmark_v1.7_PDF.pdf)):

```dockerfile
USER 1000
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD ["python", "-c", "import urllib.request as u; u.urlopen('http://127.0.0.1:5000/health', timeout=2)"]
EXPOSE 5000
CMD ["gunicorn", "-b", "0.0.0.0:5000", "app:app"]
```

The healthcheck must itself be considered by `--read-only` runtime: give it `/tmp` via tmpfs ([OWASP Docker Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)).

## Vulnerability scanning

Two complementary scanners dominate:

| Aspect | Trivy | Grype |
|--------|-------|-------|
| Coverage | Images, IaC, secrets, Kubernetes, SBOM | Focused image/package vulns, pairs with Syft SBOM |
| Extra signal | Compliance check against CIS | EPSS/KEV/VEX metadata |
| Use when | One tool for the whole pipeline | Fast, targeted scans in regulated envs |

Both pull from NVD plus distro advisories; run them together in regulated environments and rescan continuously in the registry because new CVEs appear daily ([Lucaberton Trivy vs Grype](https://lucaberton.com/blog/trivy-vs-grype-2026/), [Scaler](https://www.scaler.com/blog/what-is-container-security-scanning-trivy-grype-best-practices/), [Safeguard.sh Trivy vs Grype](https://safeguard.sh/resources/blog/trivy-vs-grype-buyer-comparison-2026)).

Gate CI on HIGH and CRITICAL findings, not zero tolerance -- a linear zero-CVE gate both rejects benign low-severity noise and spikes build failures; HIGH/CRITICAL is the defensible tripwire ([Scaler](https://www.scaler.com/blog/what-is-container-security-scanning-trivy-grype-best-practices/), [Lucaberton](https://lucaberton.com/blog/trivy-vs-grype-2026/)). Trivy exposes a direct CIS posture check used to show compliance progress: `trivy image --compliance docker-cis-1.6.0` ([unverified] per research brief). CIS Docker Benchmark is organized across host, daemon config, daemon files, images, container runtime, Swarm, and Docker EE; audits come from tools and the benchmark document itself ([OneUptime audit walkthrough](https://oneuptime.com/blog/post/2026-01-16-docker-cis-benchmarks/view), [CIS Docker Benchmark v1.7](https://rayasec.com/wp-content/uploads/CIS-Benchmark/Docker/CIS_Docker_Benchmark_v1.7_PDF.pdf)).

## Supply-chain assurance

- Generate an SBOM (SPDX/CycloneDX) for every image; attach attestations at build time ([Docker attestation basics lab](https://docs.docker.com/guides/lab-attestation-basics/)).
- Sign images with Cosign (Sigstore), keyless or key-based ([Sigstore/Cosign](https://github.com/sigstore/cosign)).
- Produce SLSA provenance (for example the container generator for GitHub Actions) so builds verifiably came from your pipeline ([SLSA container generator](https://slsa.dev/blog/2023/02/slsa-github-workflows-container-ga)).
- Publish OpenVEX statements declaring which known CVEs are not exploitable in your image, instead of un-annotated CVE noise ([Docker attestation basics lab](https://docs.docker.com/guides/lab-attestation-basics/)).
- Pin base images by digest (`image@sha256:...`), not mutable tags ([Safeguard CIS guide](https://safeguard.sh/resources/blog/docker-cis-benchmark-what-it-checks-and-how-to-pass-it)).

## NIST guidance (SP 800-190)

Container-aware operations per NIST SP 800-190: adopt container-aware vulnerability management (not host-type scanners on images), run container-aware runtime defense in place of traditional IPS/WAF inspection, control egress traffic from containers, and segment workloads by sensitivity on separate hosts ([NIST SP 800-190](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-190.pdf), [NIST ITL Bulletin Oct 2017](https://csrc.nist.gov/files/pubs/shared/itlb/itlbul2017-10.pdf)). The ITL bulletin frames container security as a shared responsibility across image, registry, orchestrator, and host ([NIST ITL Bulletin](https://csrc.nist.gov/files/pubs/shared/itlb/itlbul2017-10.pdf)). For guarding this box's own agent container (devcontainer pitfalls: lifecycle-hook RCE, token injection, bind-mount drift), see the guarding section of ai-blue-teaming.mini.md.

## Compose-level hardening sample

One place to enforce the runtime controls from the table above (5.4/5.5 capability drop, 5.11/5.12 limits, 5.13 read-only rootfs with tmpfs, 5.22 seccomp, 5.25 no-new-privileges, 4.6 healthcheck). A docker-compose service stanza consolidating them:

```yaml
services:
  app:
    image: protected-asset@sha256:abcd1234...
    user: "1000"
    read_only: true
    tmpfs:
      - /tmp
      - /run
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE
    security_opt:
      - no-new-privileges:true
      - seccomp=profile.json
    pids_limit: 512
    mem_limit: 512m
    cpus: "1.0"
    healthcheck:
      test: ["CMD", "python", "-c", "import urllib.request as u; u.urlopen('http://127.0.0.1:5000/health', timeout=2)"]
      interval: 30s
      timeout: 3s
      retries: 3
    volumes:
      - uploads:/data/uploads
volumes:
  uploads:
```

Under a read-only rootfs the writable surface is exactly the declared tmpfs and volume mounts; the composition defines the blast radius ([OWASP Docker Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html), [Opslog](https://opslog.dev/blog/docker-security-best-practices)). The `seccomp=profile.json` reference points at the runtime default profile or a curated one; the control is never disabling seccomp (5.22) ([CIS Docker Benchmark v1.7](https://rayasec.com/wp-content/uploads/CIS-Benchmark/Docker/CIS_Docker_Benchmark_v1.7_PDF.pdf)).

## Audit sequence

Run in this order on every container change ([OneUptime audit walkthrough](https://oneuptime.com/blog/post/2026-01-16-docker-cis-benchmarks/view), [Safeguard CIS guide](https://safeguard.sh/resources/blog/docker-cis-benchmark-what-it-checks-and-how-to-pass-it)):

1. `trivy image --compliance docker-cis-1.6.0` before registry push ([unverified] per research brief).
2. Trivy/Grype image scan gated on HIGH and CRITICAL; nullify known-false with OpenVEX ([Docker attestation basics lab](https://docs.docker.com/guides/lab-attestation-basics/)).
3. Secret scan of layers and the local repo (Trivy secrets modes plus pre-commit secret hooks).
4. `docker run` with the runtime flags above; `docker inspect` confirms read-only rootfs, dropped caps, no-new-privileges, seccomp.
5. Healthcheck reports healthy on `/health` before traffic is routed.
6. Record the pinned digest and SBOM in release notes with the associated finding number.

## Decision rules

- Non-root USER and read-only rootfs are mandatory minimums; everything else layers on top.
- Drop all capabilities by default; add back per app need.
- Gate CI on HIGH/CRITICAL; do not chase zero CVEs, and never suppress a scanner to pass.
- Never bake a secret into any layer; runtime injection only.
- Pin everything: base digest, dependency lockfile, pip audit.
- No privileged containers, no docker.sock, ever.

## Trigger rules

- Base image updates available: rebuild and rescan, verify the diff instead of patching the running container.
- A finding references a mutable tag or un-pinned dependency: pin and rebuild.
- A scan tripwire HIGH/CRITICAL fires: nullify (OpenVEX) or fix and rebuild; do not deploy it.
- Compose or runtime config edited by a finding: recheck 5.4-5.32 controls against the committed file.

## Final checklist

- Non-root USER and read-only rootfs in place?
- Capabilities dropped, pids/memory/CPU limited, no-new-privileges set?
- HEALTHCHECK present and reachable under read-only runtime?
- HIGH/CRITICAL scan gate clean on the final image?
- Secrets absent from layers (scan with trivy secret modes)?
- Base and deps pinned, SBOM/attestation produced?
- No docker.sock, no privileged containers in compose?

## Sources

1. CIS Docker Benchmark v1.7 (control 4.x/5.x numbering) -- https://rayasec.com/wp-content/uploads/CIS-Benchmark/Docker/CIS_Docker_Benchmark_v1.7_PDF.pdf
2. OWASP Docker Security Cheat Sheet -- https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html
3. Safeguard.sh -- Docker CIS Benchmark guide -- https://safeguard.sh/resources/blog/docker-cis-benchmark-what-it-checks-and-how-to-pass-it
4. Safeguard.sh -- Container image hardening checklist -- https://safeguard.sh/resources/blog/container-image-hardening-checklist
5. Safeguard.sh -- Trivy vs Grype buyer comparison -- https://safeguard.sh/resources/blog/trivy-vs-grype-buyer-comparison-2026
6. Opslog -- Docker security best practices -- https://opslog.dev/blog/docker-security-best-practices
7. Dash0 -- How to secure running Docker containers -- https://www.dash0.com/faq/how-to-secure-running-docker-containers
8. Sentry skills -- Docker security review -- https://github.com/getsentry/skills/blob/main/skills/security-review/infrastructure/docker.md
9. TheCodeForge -- Docker security best practices -- https://thecodeforge.io/devops/docker-security-best-practices/
10. dev-sec -- CIS Docker Benchmark controls (container runtime) -- https://github.com/dev-sec/cis-docker-benchmark/blob/master/controls/container_runtime.rb
11. Lucaberton -- Trivy vs Grype 2026 -- https://lucaberton.com/blog/trivy-vs-grype-2026/
12. Scaler -- Container security scanning best practices -- https://www.scaler.com/blog/what-is-container-security-scanning-trivy-grype-best-practices/
13. OneUptime -- Docker CIS benchmark audit walkthrough -- https://oneuptime.com/blog/post/2026-01-16-docker-cis-benchmarks/view
14. NIST SP 800-190 -- Application Container Security Guide -- https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-190.pdf
15. NIST ITL Bulletin Oct 2017 -- Container security -- https://csrc.nist.gov/files/pubs/shared/itlb/itlbul2017-10.pdf
16. Docker -- Attestation basics lab (SBOM, SLSA, Cosign, OpenVEX) -- https://docs.docker.com/guides/lab-attestation-basics/
17. SLSA -- Container generator for GitHub Actions -- https://slsa.dev/blog/2023/02/slsa-github-workflows-container-ga
18. Sigstore/Cosign -- https://github.com/sigstore/cosign
19. Optimus -- Dynamic system call filtering (Springer 2024) -- https://link.springer.com/article/10.1186/s13677-024-00639-3
20. ConLock -- Reducing runtime attack surface (2025) -- https://conand.me/publications/elkhairi-conlock-2025.pdf
21. Trivy `--compliance docker-cis-1.6.0`; UV lockfile/pip-audit guidance -- [unverified], no URL in research brief pool
