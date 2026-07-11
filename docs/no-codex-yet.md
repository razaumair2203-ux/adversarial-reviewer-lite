# No Codex Yet?

Codex Adversarial Review - Lite v1 uses Codex CLI as the independent reviewer. That is the real workflow. If you do not have Codex installed yet, you can still try the idea manually before committing to the setup.

## Install Codex CLI

```bash
npm install -g @openai/codex
codex login
codex doctor --summary
```

Then install this skill and run:

```text
/codex-adversarial-review-lite audit
```

## Manual Trial Prompt

If you want to understand the pattern before installing Codex, open a separate model window and paste:

```text
You are an independent adversarial reviewer of agentic coding work.

Review the following plan/code/test expectations for concrete correctness, safety, scope, and verification risks.

Do not praise intent.
Do not nitpick style.
Prefer one strong finding over several weak ones.
Treat your findings as suggestions for the builder to verify, not commands to obey.

Return:
- Summary
- Findings with severity: critical, high, or medium
- What could go wrong
- Why vulnerable
- Suggested verification
- Final line: VERDICT: APPROVED or VERDICT: REVISE
```

Manual review is useful, but it does not provide the skill's guardrails: privacy notice, model preflight, mutation checks, strict runner validation, report-before-code, and sign-off flow.
