# Safety Model

Codex Adversarial Review - Lite is a workflow guardrail, not a hard security sandbox.

## Trust Boundaries

The builder and reviewer are both AI systems. Neither is automatically trusted.

The workflow assumes:

- the reviewer can be wrong;
- the builder can be wrong;
- command output can be misunderstood;
- local files can be dirty before review starts;
- Windows sandboxing can be weaker than Linux sandboxing.

## Controls

Codex Adversarial Review - Lite includes:

- local tool preflight for Git, Codex CLI, timeout, grep/tail, and SHA-256 hashing;
- setup-needed prompt when prerequisites are missing, before any external reviewer dispatch;
- model preflight before expensive review;
- privacy notice before repository content is sent to the reviewer backend;
- audit-first default flow for the first public release;
- focused test specifications and test data passed into review when available;
- reviewer permissions that forbid project-file edits;
- approval policy controls for the reviewer backend;
- pre/post Git status snapshots;
- content hashing for already-dirty tracked files;
- hard stop on detected project mutation;
- explicit accept/reject/re-scope/defer decisions for reviewer findings;
- empirical verification for tool, CLI, package, config, and API claims when practical;
- a structural-change gate for workflow, sandbox, data, and architecture changes;
- audit-mode sign-off before fixes;
- optional HTML report with decisions and fix log;
- report-before-code discipline: the builder presents validated findings and the HTML option before applying fixes.

## Known Limits

Codex Adversarial Review - Lite does not:

- prove code correctness;
- replace tests;
- prevent a reviewer backend from seeing repo content;
- protect ignored secret files inside the repo;
- guarantee sandboxing on Windows;
- guarantee the reviewer model supports the requested model name;
- install missing tools without explicit user approval. The skill can detect and install missing prerequisites, but only after showing the full list and receiving a clear yes from the user. It never installs silently.
- guarantee hash-based mutation detection when temp file paths or shell variables are misconfigured. On Windows, Git Bash `/tmp` and the platform-native temp path can diverge between tools. If hash files are empty due to variable expansion failure or path mismatch, the pre/post mutation comparison produces a false-negative (no diff detected). The skill mitigates this with non-empty hash verification steps, but the underlying risk exists when Claude Code's Bash tool calls do not correctly redeclare variables. See "Claude Code Runtime Notes" in SKILL.md.

## Recommended Use

Use `audit` mode for first-time or high-risk reviews:

```text
/codex-adversarial-review-lite audit
```

Do not rely on automatic prompting. Invoke the skill intentionally after an agentic coding change or before approving a risky plan.

If you want reminders, paste `snippets/claude-md-reminder.md` into your project `CLAUDE.md`. The reminder should suggest the audit; it should not run the audit automatically.

For sensitive work, commit or stash first so mutation detection has a clean baseline.

For better audits, provide focused test expectations:

```text
/codex-adversarial-review-lite audit test-spec:docs/change-tests.md test-data:fixtures/change-cases.json
```

Keep them exhaustive for the requested change, but avoid unrelated scenarios that widen scope.

## Approval Policy Options

The public skill exposes:

```text
approvals:auto_review
approvals:user
approvals:never
```

`auto_review` is the default because it reduces the chance that the reviewer hangs inside a nested approval prompt that the user cannot see. Use `user` when you want to personally approve nested reviewer requests. Use `never` for stricter non-interactive runs where the reviewer should fail instead of asking.
