# OBEY AI Blue Teaming -- blue-team condensed reference

## Citation note

Every factual claim cites a source inline and is grounded in the approved research-brief URL pool. `[unverified]` marks a named source or control that has no URL in the pool; its content is taken from the research brief, which remains the authority.

## When to use

Use when hardening the LLM-agent surface of the protected asset or of this box's own agent stack: granting tools, gating high-impact actions, monitoring runtime behavior, and sealing devcontainer/agent-hosting pitfalls. Primary audience: all three blue-team agents, since the agent stack of this box is itself an LLM application.

## Primary bias to correct

Believing the LLM can be made to "just behave". An LLM is an untrusted component: instructions and data share one channel, so prompt injection is unavoidable at the model layer. Security moves into deterministic systems around the model -- least-privilege tool grants, policy enforcement on tool calls, human gates, monitoring, and logging ([OWASP LLM01:2025](https://genai.owasp.org/download/43299/), [OWASP LLM06:2025](https://owasp.org/www-project-top-10-for-large-language-model-applications/2_0_vulns/LLM06_ExcessiveAgency)).

## Threat model at a glance

- Direct prompt injection: user prompts override instructions ([OWASP LLM01:2025](https://genai.owasp.org/download/43299/)).
- Indirect prompt injection: adversary content in documents, emails, or tool output steers the model; the user sees no sign of compromise ([OWASP LLM01:2025](https://genai.owasp.org/download/43299/)).
- Output handling: unsanitized model output flowing into HTML, SQL, or shell positions turns the model into an access broker (XSS/CSRF/SSRF/RCE vectors) ([OWASP LLM05:2025](https://owasp.org/www-project-top-10-for-large-language-model-applications/2_0_vulns/LLM05_ImproperOutputHandling)).
- Excessive agency: extra functionality, permissions, or autonomy lets a manipulated response take real action; blast radius multiplies ([OWASP LLM06:2025](https://owasp.org/www-project-top-10-for-large-language-model-applications/2_0_vulns/LLM06_ExcessiveAgency), [Agen.co OWASP analysis](https://agen.co/learning-center/owasp-top-10-for-llm)).

## Least-privilege tool grants (LLM06:2025)

Define per-tool least-privilege profiles: scopes, maximum rate, and egress allowlists. Database tools get read-only queries, email summarizers get no send/delete rights, and exposed APIs get minimal CRUD ([OWASP LLM06:2025](https://owasp.org/www-project-top-10-for-large-language-model-applications/2_0_vulns/LLM06_ExcessiveAgency), [Progent privilege control](https://arxiv.org/pdf/2504.11703)). Enforce via IAM policy stanzas and middleware, not ad-hoc conventions. Minimize tools, functions, and permissions; execute in the user's context; require approval for high-impact actions ([OWASP LLM06:2025](https://owasp.org/www-project-top-10-for-large-language-model-applications/2_0_vulns/LLM06_ExcessiveAgency)).

## Monotonic confinement (Progent)

Policy enforcement via an SMT solver: each proposed policy update is checked to see whether it narrows privileges (auto-applied) or expands them (requires explicit approval). Even if the LLM is manipulated by adversarial inputs, the deterministic check prevents silent privilege escalation. In Progent's findings an initial LLM-generated policy alone dropped attack success from 39.9% to 2.5% ([Progent, arXiv 2504.11703](https://arxiv.org/pdf/2504.11703)). Use the same narrowing gate for any tool-credential policy your agents can draught.

## Human-in-the-loop gates

Require human approval for high-impact or irreversible actions: delete, transfer, publish, fund transfer. Present a pre-execution plan or dry-run diff before approval, and recall the OWASP guidance -- a human should approve high-impact actions before they are taken ([OWASP LLM06:2025](https://owasp.org/www-project-top-10-for-large-language-model-applications/2_0_vulns/LLM06_ExcessiveAgency), [OWASP Agentic Top 10 2026 ASI02](https://genai.owasp.org/download/52117)). This box already runs HITL for push and close; extend the same gate to any action an agent can trigger through a tool.

## Runtime monitoring and guardrails

Monitor model outputs, reasoning traces, and tool calls across four enforcement points: before the model (input guardrails), around retrieval, after the model (output guardrails), and around tool calls. This catches prompt injection, data exfiltration, and policy drift ([Alice.io LLM guardrails](https://alice.io/blog/llm-guardrails)). Combine behavior and reasoning analysis for higher detection rates, as runtime monitoring tooling such as Adrian demonstrates for agent security agents ([Adrian runtime agent security](https://github.com/secureagentics/Adrian)). Every guardrail decision must be logged.

## Intent gate: verify tool calls before execution

Treat LLM-suggested tool calls as untrusted. Insert a pre-execution policy enforcement point (PEP/PDP) that validates intent and argument schema, enforces rate limits, and issues short-lived credentials. The governing principle from the Agentic Top 10: implement authorization in logic and downstream systems rather than relying on the LLM to decide whether an action is allowed ([OWASP Agentic Top 10 2026 ASI02](https://genai.owasp.org/download/52117)). Least-privilege frameworks such as MiniScope bind tools to the minimal permission set needed for a task ([MiniScope least privilege framework](https://www.alphaxiv.org/abs/2512.11147)).

AgentPerms operationalizes the loop as record-infer-lock-replay-enforce: record agent tool calls, auto-infer minimum permissions, generate a policy, prove it blocks the dangerous calls (SSH key exfiltration, env secret read, shell exec, force push, repo deletion), then enforce in CI and at runtime so denied calls never reach the server ([AgentPerms](https://github.com/hasanmehmood/agentperms)).

| Enforcement point | Check | Fail-to action |
|-------------------|-------|----------------|
| Before model | Input guardrails: jailbreak/instruction-override patterns | Block or paraphrase |
| Around retrieval | Retrieved-context poisoning, schema drift | Drop poisoned chunks |
| After model | Output schema validation, encoding before sinks | Reject, sanitize |
| Around tool calls | Intent gate: tool, args, rate, allowance | Deny before execution |

## Adaptive tool budgeting and circuit breakers

Apply usage ceilings: cost, rate, token budgets, invocation counts, and cumulative parameter values, with automatic revocation or throttling. Circuit breakers halt, rate-limit, or escalate for human review once thresholds trip ([OWASP Agentic Top 10 2026](https://genai.owasp.org/download/52117)). Budgets double as detection -- an anomalous tool-call burst is both a security signal and a cost control.

## Comprehensive logging

Write an evidence record for every guardrail decision: policy version, user identity, request, retrieved context, model output, tool calls, guardrail verdict, latency ([Alice.io LLM guardrails](https://alice.io/blog/llm-guardrails)). Keep immutable logs of every tool invocation and parameter change so drift and post-incident reconstruction are possible ([OWASP Agentic Top 10 2026](https://genai.owasp.org/download/52117)). Without this record, a "did your agent do it?" question cannot be answered.

## OWASP Top 10 for LLM Applications 2025

| Risk | 2025 class | Blue-team posture |
|------|-----------|-------------------|
| LLM01 | Prompt injection (#1, two editions running) | Constrain via system prompt, validate outputs, segregate external content, enforce privileges ([OWASP LLM01:2025](https://genai.owasp.org/download/43299/), [Invicti analysis](https://www.invicti.com/blog/web-security/owasp-top-10-risks-llm-security-2025)) |
| LLM02 | Sensitive information disclosure (up to #2) | Do not place secrets/roles in system prompts; leak-test outputs ([OWASP Top 10 for LLM Applications 2025](https://owasp.org/www-project-top-10-for-large-language-model-applications/assets/PDF/OWASP-Top-10-for-LLMs-v2025.pdf)) |
| LLM05 | Improper output handling (down to #5) | Treat model as an untrusted user; context-aware encoding; parameterized queries for model-driven DB writes ([OWASP LLM05:2025](https://owasp.org/www-project-top-10-for-large-language-model-applications/2_0_vulns/LLM05_ImproperOutputHandling)) |
| LLM06 | Excessive agency (new) | Least-privilege tools, monotonic policy, HITL gate ([OWASP LLM06:2025](https://owasp.org/www-project-top-10-for-large-language-model-applications/2_0_vulns/LLM06_ExcessiveAgency)) |
| LLM07 | System prompt leakage (new) | Never embed API keys, tokens, or roles in system prompts; never treat the system prompt as a security boundary; external guardrails enforce critical controls ([Agen.co](https://agen.co/learning-center/owasp-top-10-for-llm)) |
| LLM08 | Vector/embedding weaknesses (new) | Tenant-isolate and access-control vector stores; validate content before embedding; monitor for anomalous embeddings ([Agen.co](https://agen.co/learning-center/owasp-top-10-for-llm)) |

Key 2025 shift: when a model can only emit text, worst case is a bad answer; when it can call tools, the blast radius of one prompt injection or one over-privileged tool expands dramatically ([Agen.co](https://agen.co/learning-center/owasp-top-10-for-llm)). Supply chain moves up to #3 and broadens to include models, plugins, and datasets ([Invicti](https://www.invicti.com/blog/web-security/owasp-top-10-risks-llm-security-2025)).

## OWASP Top 10 for Agentic Applications 2026

Extends the LLM list to agent-specific risks: ASI02 tool misuse and exploitation, ASI03 identity and privilege abuse, ASI06 memory and context poisoning. Core principle: Least Agency -- deploy agentic autonomy only where needed, avoid unnecessary autonomy, and treat strong observability as non-negotiable ([OWASP Agentic Top 10 2026](https://genai.owasp.org/download/52117)). Configured with the A01-broken-access-control lens of triage-and-severity.mini.md, an agent tool misused is an authorization bug with a prompt as its trigger.

## Guarding this box's own agent stack (devcontainer pitfalls)

The blue team box runs its agents inside a devcontainer with tokens injected as environment variables, so it must secure its own host surface, not just the target ([Threadlinqs Codespaces RCE](https://threadlinqs.com/blog/TL-2026-0100-github-codespaces-rce/), [Orca Security](https://orca.security/resources/blog/hacking-github-codespaces-rce-supply-chain-attack/)):

- Lifecycle hooks are code execution: `initializeCommand` runs on the HOST before any container exists, `postCreateCommand` runs inside with access to `GITHUB_TOKEN` and secrets. A malicious repo can exfiltrate tokens ([Threadlinqs](https://threadlinqs.com/blog/TL-2026-0100-github-codespaces-rce/), [Orca Security](https://orca.security/resources/blog/hacking-github-codespaces-rce-supply-chain-attack/)). Prefer short-lived OIDC federated credentials over static secrets ([Safeguard.sh Codespaces security model](https://safeguard.sh/resources/blog/github-codespaces-security-model-2022)).
- Tokens are env vars readable by every process, including installed npm/pip packages; default `GITHUB_TOKEN` carries write scopes (`contents:write`, `pull-requests:write`, `issues:write`). Restrict to read-only where write is not needed ([AquilaX](https://aquilax.ai/blog/remote-dev-environment-codespaces-security)). The known leak of tokens into remote pods argues for scope/rotate discipline ([vscode-remote issue](https://github.com/microsoft/vscode-remote-release/issues/10976)).
- Bind-mounted workspaces let container-written `.git/hooks` and modified scripts execute on the host later; prefer clone-in-volume for security-sensitive work ([safer-codespace](https://github.com/nicomarr/safer-codespace/)).
- Extensions install into the container with filesystem, env, and network access; a compromised extension exfiltrates source via outbound HTTPS ([AquilaX](https://aquilax.ai/blog/remote-dev-environment-codespaces-security), [Threadlinqs](https://threadlinqs.com/blog/TL-2026-0100-github-codespaces-rce/)).
- `SSH_AUTH_SOCK` and agent env vars are injected into the container and can push as the developer; override with `remoteEnv` plus hardening ([Dan Demmel, coding agents in secured dev containers](https://www.danieldemmel.me/blog/coding-agents-in-secured-vscode-dev-containers)).
- `.vscode/settings.json` `PROMPT_COMMAND` and auto-run tasks (`.vscode/tasks.json` with `task.allowAutomaticTasks`) are independent execution vectors alongside devcontainer hooks ([Orca Security](https://orca.security/resources/blog/hacking-github-codespaces-rce-supply-chain-attack/)).
- Mitigations: CODEOWNERS on `.devcontainer/` changes requiring security review, egress control via corporate proxy, short-lived OIDC, read-only token scopes, egress allowlists enforced outside the container ([Safeguard.sh Codespaces model](https://safeguard.sh/resources/blog/github-codespaces-security-model-2022), [safer-codespace](https://github.com/nicomarr/safer-codespace/)).

## Blueprint: hardening this box's own agent stack

Consolidating the devcontainer mitigations from the guarding section into an ordered hardening list:

1. CODEOWNERS: require a security-team review for any PR touching `.devcontainer/` or `.vscode/` (hooks, tasks.json, settings.json) ([Safeguard.sh Codespaces security model](https://safeguard.sh/resources/blog/github-codespaces-security-model-2022), [safer-codespace](https://github.com/nicomarr/safer-codespace/)).
2. Token scope hygiene: default `GITHUB_TOKEN` to read-only where writes are not needed; scope org/repo Codespaces secrets to specific repos only ([AquilaX](https://aquilax.ai/blog/remote-dev-environment-codespaces-security)).
3. Short-lived OIDC federated credentials in place of static secrets for any cloud access ([Safeguard.sh Codespaces security model](https://safeguard.sh/resources/blog/github-codespaces-security-model-2022)).
4. Override injected agent socket env vars (`SSH_AUTH_SOCK`, `GPG_AGENT_INFO`, `VSCODE_IPC_HOOK_CLI`) via `remoteEnv` and clean them up after use so they cannot push as the developer ([Dan Demmel](https://www.danieldemmel.me/blog/coding-agents-in-secured-vscode-dev-containers)).
5. Route agent egress through a corporate proxy and enforce allowlists outside the container so a compromised agent cannot exfiltrate over arbitrary HTTPS ([Safeguard.sh Codespaces security model](https://safeguard.sh/resources/blog/github-codespaces-security-model-2022)).
6. Prefer clone-in-volume over bind-mounting a host folder for agent work; a bind mount lets container-written `.git/hooks` or scripts run on the host later ([safer-codespace](https://github.com/nicomarr/safer-codespace/)).
7. Harden the agent box's own image the same way as the protected asset: non-root, read-only rootfs, dropped capabilities, no-new-privileges ([OWASP Docker Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)).
8. Audit installed extensions: a compromised extension has filesystem, env, and network access indistinguishable from telemetry ([AquilaX](https://aquilax.ai/blog/remote-dev-environment-codespaces-security), [Threadlinqs](https://threadlinqs.com/blog/TL-2026-0100-github-codespaces-rce/)).

## Agent tool policy template

Per-operation policy rows the intent gate applies, showing the least-privilege shape expected for every tool ([OWASP LLM06:2025](https://owasp.org/www-project-top-10-for-large-language-model-applications/2_0_vulns/LLM06_ExcessiveAgency), [MiniScope](https://www.alphaxiv.org/abs/2512.11147)):

| Tool | Allowed scopes | Rate ceiling | Egress allowlist | Human gate |
|------|----------------|--------------|------------------|------------|
| repo-read | Clone, fetch, read refs | 10/min | github.com API | never |
| issue-close | Close only the listed issue(s) | 5/hour | github.com API | always |
| find-and-replace | Files under `app/` only | 3/min | none (local) | never |
| credential-rotate | Rotate, never read back | 1/hour | vault.internal | always |

Each row is checked monotonically: any change that broadens a row requires explicit human approval before the intent gate accepts it; narrowing is auto-applied ([Progent](https://arxiv.org/pdf/2504.11703)).

## Decision rules

- Enforce authorization in logic and downstream systems, never in the LLM.
- Tools get least privilege by default; HITL gates sit on every irreversible action.
- Output that flows into HTML, SQL, or shell is encoded or parameterized at the sink.
- Every tool call passes an intent gate; every gate decision is logged, immutably.
- System prompts never carry secrets; system prompts never act as a security boundary.
- Monitor across all four enforcement points continuously.

## Trigger rules

- A tool is granted broader scope than its task needs: narrow it or refuse the grant.
- A policy update would expand privileges: block it unless a human explicitly approves.
- A tool-call burst trips a budget/circuit-breaker threshold: throttle, revoke, escalate.
- A devcontainer config PR touches hooks, tasks, or token scopes: route through CODEOWNERS.
- A prompt-injection-like trace appears in logs: treat as incident, replay, and add detection.

## Final checklist

- Least-privilege profiles enforced per tool, with monotonic narrowing?
- HITL gate on every irreversible action, pre-execution plan shown?
- Intent gate denies before execution; circuit breakers and budgets armed?
- Guardrail verdicts logged with policy version and evidence for every decision?
- System prompts free of secrets, and no reliance on them as a boundary?
- Devcontainer hooks, tasks, and token scopes sealed (CODEOWNERS, OIDC, read-only)?

## Sources

1. OWASP LLM01:2025 -- Prompt injection -- https://genai.owasp.org/download/43299/
2. OWASP LLM05:2025 -- Improper output handling -- https://owasp.org/www-project-top-10-for-large-language-model-applications/2_0_vulns/LLM05_ImproperOutputHandling
3. OWASP LLM06:2025 -- Excessive agency -- https://owasp.org/www-project-top-10-for-large-language-model-applications/2_0_vulns/LLM06_ExcessiveAgency
4. OWASP Top 10 for LLM Applications 2025 (PDF) -- https://owasp.org/www-project-top-10-for-large-language-model-applications/assets/PDF/OWASP-Top-10-for-LLMs-v2025.pdf
5. OWASP Top 10 for Agentic Applications 2026 (ASI02/ASI03/ASI06, Least Agency) -- https://genai.owasp.org/download/52117
6. Invicti -- OWASP Top 10 for LLMs 2025 analysis -- https://www.invicti.com/blog/web-security/owasp-top-10-risks-llm-security-2025
7. Agen.co -- OWASP Top 10 for LLM risks and mitigations -- https://agen.co/learning-center/owasp-top-10-for-llm
8. Progent -- privilege control framework for AI agents (arXiv 2504.11703) -- https://arxiv.org/pdf/2504.11703
9. MiniScope -- least privilege framework -- https://www.alphaxiv.org/abs/2512.11147
10. AgentPerms -- record-infer-lock-replay-enforce -- https://github.com/hasanmehmood/agentperms
11. Alice.io -- LLM guardrails: prompts, outputs, RAG, agents -- https://alice.io/blog/llm-guardrails
12. Adrian -- runtime agent security monitoring -- https://github.com/secureagentics/Adrian
13. Threadlinqs -- GitHub Codespaces RCE via devcontainer.json -- https://threadlinqs.com/blog/TL-2026-0100-github-codespaces-rce/
14. Orca Security -- Hacking GitHub Codespaces RCE -- https://orca.security/resources/blog/hacking-github-codespaces-rce-supply-chain-attack/
15. AquilaX -- remote dev environment security -- https://aquilax.ai/blog/remote-dev-environment-codespaces-security
16. Safeguard.sh -- GitHub Codespaces security model -- https://safeguard.sh/resources/blog/github-codespaces-security-model-2022
17. nicomarr/safer-codespace -- https://github.com/nicomarr/safer-codespace/
18. Dan Demmel -- coding agents in secured dev containers -- https://www.danieldemmel.me/blog/coding-agents-in-secured-vscode-dev-containers
19. vscode-remote-release issues #10976 (token leak to remote pod) -- https://github.com/microsoft/vscode-remote-release/issues/10976
20. OWASP Docker Security Cheat Sheet -- https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html
