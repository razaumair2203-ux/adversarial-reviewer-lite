---
name: adversarial-reviewer-lite
description: Adversarial Reviewer Lite: user-invoked audit workflow for Claude Code users who want Codex CLI to independently review AI-generated code, plans, test expectations, and scope before fixes are applied. Use only when the user explicitly invokes audit.
user-invocable: true
disable-model-invocation: true
argument-hint: "audit [path] [reviewer:<model>] [test-spec:<path>] [test-data:<path>]"
---

# Adversarial Reviewer Lite

Adversarial Reviewer Lite is a Claude Code skill. It asks Codex CLI to independently audit Claude Code's plan, code changes, and focused test expectations before the builder trusts the work or applies fixes.

Tested setup:

- Builder: Claude Code
- Reviewer backend: Codex CLI
- Default reviewer model: `gpt-5.5`
- Default reviewer reasoning: `xhigh`

Version 1 is intentionally focused: Claude Code as builder, Codex CLI as reviewer, Windows-aware defaults, and audit mode as the recommended path. The `builder`, `reviewer`, and `review_backend` terms keep the design portable later, but v1 is not a general multi-agent framework.

## Invocation

Recommended v1 user invocation:

- `/adversarial-reviewer-lite audit` - one reviewer pass, builder validates findings, report/HTML option is presented, user signs off before fixes.

Advanced scope hints:

- `/adversarial-reviewer-lite audit <file-path>` - audit a specific file or plan.
- `/adversarial-reviewer-lite audit test-spec:<path>` - audit with focused test expectations.
- `/adversarial-reviewer-lite audit test-data:<path>` - audit with focused sample data or fixtures.

Options:

- `reviewer:<model>` - default `gpt-5.5`.
- `reasoning:low|medium|high|xhigh` - default `xhigh`.
- `sandbox:workspace-write|read-only|danger-full-access|inherit` - default Unix `workspace-write`, default Windows `danger-full-access`.
- `approvals:user|auto_review|never` - default `auto_review`.
- `test-spec:<path>` - focused test expectations, scenarios, or validation commands to pass to the reviewer.
- `test-data:<path>` - sample inputs, fixtures, edge cases, or regression data to pass to the reviewer.
- `backend:codex` - default and only implemented backend in v1.

Convenience aliases:

- `model:<model>` means `reviewer:<model>`.
- Bare `low`, `medium`, `high`, `xhigh` set reasoning.
- Bare `audit` sets audit mode.
- If `audit` is absent, stop and ask the user to invoke `/adversarial-reviewer-lite audit ...`.

## Runtime Language

Infer `OPERATOR_LANGUAGE` from recent user messages. Render runtime prose, summaries, warnings, and beginner explanations in that language when practical.

Keep machine-readable literals in English exactly as written:

- `VERDICT: APPROVED`
- `VERDICT: REVISE`
- `[severity: critical|high|medium]`
- JSON field names
- command names and option names
- temporary file names

## Step 1: Capture Settings

Parse user arguments:

- `MODE`: must be `audit` for v1 public use.
- `AUDIT_MODE`: true only when `audit` is explicitly present.
- `REVIEW_BACKEND`: default `codex`.
- `REVIEWER_MODEL`: default `gpt-5.5`.
- `REVIEWER_REASONING`: default `xhigh`.
- `REVIEWER_SANDBOX`: default `workspace-write`.
- `REVIEWER_APPROVAL_MODE`: default `auto_review`.
- `TEST_SPEC_PATHS`: zero or more files from `test-spec:<path>`.
- `TEST_DATA_PATHS`: zero or more files from `test-data:<path>`.
- `OPERATOR_LANGUAGE`: inferred from recent user messages; default English.

Map approval mode for Codex backend:

| User option | `approval_policy` | `approvals_reviewer` | Use when |
|---|---|---|---|
| `approvals:auto_review` | `on-request` | `auto_review` | Default; avoids hidden hangs while still requiring review for boundary-crossing operations. |
| `approvals:user` | `on-request` | unset | The user wants to approve nested reviewer requests directly. |
| `approvals:never` | `never` | unset | CI-like, no interactive approval; reviewer must stay inside allowed operations. |

Set:

- `REVIEWER_APPROVAL_POLICY`
- `REVIEWER_APPROVALS_REVIEWER`

If `REVIEW_BACKEND` is anything other than `codex`, stop with:

```text
Adversarial Reviewer Lite v1 only implements backend:codex. Other backends are planned but not available yet.
```

If the user did not explicitly invoke `audit`, stop with:

```text
Adversarial Reviewer Lite v1 is audit-first and does not auto-select audit mode. Please invoke `/adversarial-reviewer-lite audit ...` so the report-before-code sign-off path is explicit.
```

## Step 2: Preflight, Platform, And Repo

Before any Git or reviewer work, check local prerequisites:

```bash
MISSING_ADVREVIEW_PREREQS=""

command -v git >/dev/null 2>&1 || MISSING_ADVREVIEW_PREREQS="${MISSING_ADVREVIEW_PREREQS}
- git: required for repo detection and mutation snapshots. Install Git for Windows, Git Bash, or WSL."

command -v codex >/dev/null 2>&1 || MISSING_ADVREVIEW_PREREQS="${MISSING_ADVREVIEW_PREREQS}
- codex: required for backend:codex. Install with npm install -g @openai/codex, then run codex login."

command -v timeout >/dev/null 2>&1 || MISSING_ADVREVIEW_PREREQS="${MISSING_ADVREVIEW_PREREQS}
- timeout: required for safe non-interactive reviewer runs. Use Git Bash, WSL, or GNU coreutils."

command -v grep >/dev/null 2>&1 || MISSING_ADVREVIEW_PREREQS="${MISSING_ADVREVIEW_PREREQS}
- grep: required for runner validation. Use Git Bash, WSL, or grep-compatible tooling."

command -v tail >/dev/null 2>&1 || MISSING_ADVREVIEW_PREREQS="${MISSING_ADVREVIEW_PREREQS}
- tail: required for runner validation. Use Git Bash, WSL, or GNU coreutils."

command -v cat >/dev/null 2>&1 || MISSING_ADVREVIEW_PREREQS="${MISSING_ADVREVIEW_PREREQS}
- cat: required for prompt assembly. Use Git Bash, WSL, or GNU coreutils."

command -v sort >/dev/null 2>&1 || MISSING_ADVREVIEW_PREREQS="${MISSING_ADVREVIEW_PREREQS}
- sort: required for dirty-file snapshots. Use Git Bash, WSL, or GNU coreutils."

if [ -n "${MISSING_ADVREVIEW_PREREQS}" ]; then
  printf '%s\n' "Adversarial Reviewer Lite setup needed. I cannot start the audit yet because these prerequisites are missing:"
  printf '%s\n' "${MISSING_ADVREVIEW_PREREQS}"
  printf '%s\n' ""
  printf '%s\n' "Install the missing tools, restart/reopen the Claude Code shell if PATH changed, then re-run:"
  printf '%s\n' "/adversarial-reviewer-lite audit"
  printf '%s\n' ""
  printf '%s\n' "Setup help: docs/how-to-use.md and docs/troubleshooting.md in the adversarial-reviewer-lite repo."
  exit 1
fi
```

Choose a hash command:

```bash
if command -v sha256sum >/dev/null 2>&1; then
  HASH_CMD="sha256sum"
elif command -v shasum >/dev/null 2>&1; then
  HASH_CMD="shasum -a 256"
else
  echo "Adversarial Reviewer Lite setup needed. A SHA-256 tool is required for dirty-file mutation checks. Install coreutils for sha256sum or Perl shasum, restart the shell if PATH changed, then re-run /adversarial-reviewer-lite audit. See docs/troubleshooting.md."
  exit 1
fi
```

Run a Codex health check when available:

```bash
if codex doctor --help >/dev/null 2>&1; then
  if timeout 15 codex doctor --summary >/dev/null 2>&1; then
    true
  else
    echo "Adversarial Reviewer Lite setup needed. Codex CLI health check failed. Run codex doctor --summary, fix auth/config/runtime issues, then re-run /adversarial-reviewer-lite audit. See docs/troubleshooting.md."
    exit 1
  fi
else
  echo "Codex doctor is not available in this Codex CLI version; continuing to model preflight."
fi
```

If `codex doctor` is not available in an older Codex CLI, skip this health check and rely on the model preflight in Step 6.

When a prerequisite is missing, do not dispatch the runner, do not send repo context to Codex, and do not attempt installation silently. Present the setup-needed message in `OPERATOR_LANGUAGE`. If the missing prerequisite can be installed safely from the shell, ask for explicit user approval before running an install command. Otherwise, give manual install steps and stop.

Capture `REPO_ROOT`:

```bash
git rev-parse --show-toplevel
```

If not inside a Git worktree, stop. Adversarial Reviewer Lite needs Git snapshots for mutation detection.

Detect Windows in two ways:

- `uname -o` returns `Msys`, `Cygwin`, or `unknown`;
- `REPO_ROOT` starts with a drive letter such as `C:\` or `E:/`.

On Windows:

- set `PLATFORM=windows`;
- if the user did not pass `sandbox:*`, set `REVIEWER_SANDBOX=danger-full-access`;
- emit:

```text
Windows detected. Adversarial Reviewer Lite set reviewer sandbox to danger-full-access because bwrap is usually unavailable on Windows. The reviewer is instructed not to edit files, and Adversarial Reviewer Lite will compare Git status plus dirty-file hashes before any fixes are applied. Use sandbox:inherit only if your Codex CLI config supports a safer Windows-native mode.
```

On Unix/macOS, keep `REVIEWER_SANDBOX=workspace-write` unless overridden.

## Step 3: Privacy Notice

Before sending any repository content to the reviewer backend, emit once per session:

```text
External reviewer (${REVIEWER_MODEL} via ${REVIEW_BACKEND}) will receive repository context including file contents, diffs, command output, and the review prompt. Continue only if this is acceptable for this repo.
```

If the user declines, stop.

## Step 4: Prepare Review Scope

V1 is audit-first and user-invoked. Do not auto-select audit mode. If the user asks for review without `audit`, stop and ask them to re-run with `/adversarial-reviewer-lite audit ...`. Plans, code diffs, and plan/implementation consistency checks are scope concepts inside audit, not separate public modes.

When the audit includes a plan:

- use the provided plan file if one exists;
- otherwise write a temporary plan file from conversation context;
- show the plan path to the user.

When the audit includes code changes:

- collect changed files from `git diff --name-only` and `git diff --cached --name-only`;
- if both are empty, fall back to branch diff against `origin/main`, `main`, or `master`;
- if no changes exist, tell the user there is nothing to review.

When the audit includes both a plan and code changes:

- include both the plan path and code diff commands;
- ask the reviewer to check whether the implementation matches the stated plan;
- flag unplanned behavior as possible scope creep.

When the audit includes test specifications and test data:

- include every explicit `test-spec:<path>` and `test-data:<path>` file;
- extract focused expectations from conversation context when no file is provided;
- pass expected behavior, edge cases, fixtures, regression scenarios, and normal validation commands to the reviewer;
- keep the test bundle exhaustive for the requested change but focused on the user's scope;
- warn if test data appears to contain secrets, credentials, or private customer data.

When collecting content, avoid ignored files unless the user explicitly asks for them. Warn if the requested scope appears to include secrets, credentials, or private customer data.

## Step 5: Mutation Snapshot Before Review

Create a unique `REVIEW_ID` using this format:

```text
<unix_timestamp>-<random_8digit_number>
```

Example:

```text
1767139200-48392017
```

Use only digits and one hyphen. Do not use spaces, slashes, colons, or user-provided text in `REVIEW_ID`.

Choose `TMP_ROOT`, outside the repo and outside any push path:

- Unix/macOS: `/tmp`
- Windows Git Bash/MSYS, which is the usual Claude Code shell on Windows: `${TMPDIR:-/tmp}/adversarial-reviewer-lite`
- Windows PowerShell only if your agent host is explicitly running PowerShell: `$env:TEMP\adversarial-reviewer-lite`

Create it if needed. All examples below use `${TMP_ROOT}`.

Capture repo status:

```bash
git -C "${REPO_ROOT}" status --porcelain > "${TMP_ROOT}/advreview-git-pre-${REVIEW_ID}.txt"
```

If tracked files are already dirty, capture their paths and hash their current contents with filename plus hash:

```bash
git -C "${REPO_ROOT}" diff --name-only \
  > "${TMP_ROOT}/advreview-dirty-files-${REVIEW_ID}.txt"
git -C "${REPO_ROOT}" diff --cached --name-only \
  >> "${TMP_ROOT}/advreview-dirty-files-${REVIEW_ID}.txt"
sort -u -o \
  "${TMP_ROOT}/advreview-dirty-files-${REVIEW_ID}.txt" \
  "${TMP_ROOT}/advreview-dirty-files-${REVIEW_ID}.txt"

while read f; do
      h=$(git -C "${REPO_ROOT}" hash-object "$f" 2>/dev/null || true)
      printf '%s  %s\n' "$h" "$f"
    done < "${TMP_ROOT}/advreview-dirty-files-${REVIEW_ID}.txt" \
  > "${TMP_ROOT}/advreview-dirty-pre-${REVIEW_ID}.sha"
```

This closes the gap where `git status --porcelain` cannot detect content changes to files that were already modified before review.

Pass `advreview-dirty-files-${REVIEW_ID}.txt` to the runner as a do-not-touch warning list. The main skill still owns enforcement. If a dirty-file hash changes, stop before applying fixes.

## Step 6: Model Preflight

Run once before the first reviewer dispatch.

Choose `PREFLIGHT_SANDBOX`:

- if `REVIEWER_SANDBOX=inherit`, omit `-s`;
- if `PLATFORM=windows` and the selected sandbox is `read-only` or `workspace-write`, use `danger-full-access` for model preflight only and warn that this checks model/auth availability, not sandbox viability;
- otherwise use the same sandbox as the review.

Example:

```bash
timeout 30 codex exec -m ${REVIEWER_MODEL} -s ${PREFLIGHT_SANDBOX} \
  "Reply with exactly the text MODEL_OK and nothing else" \
  -o "${TMP_ROOT}/advreview-preflight-${REVIEW_ID}.txt" \
  2>"${TMP_ROOT}/advreview-preflight-err-${REVIEW_ID}.txt"
```

If `REVIEWER_SANDBOX=inherit`, omit `-s ${PREFLIGHT_SANDBOX}`.

If the output file contains `MODEL_OK`, continue.

If stderr indicates model, auth, quota, or login failure, stop with:

```text
Reviewer model "${REVIEWER_MODEL}" is not available through Codex CLI. Check the model name, auth, quota, or API key.
```

If preflight times out after 30 seconds, warn the user and continue. Do not treat a timeout as proof the model works.

## Step 7: Build Reviewer Prompt

Use this reviewer stance for all modes:

```text
You are an independent reviewer of agentic coding work.
Your job is to find concrete correctness, safety, scope, and verification risks.
Do not praise the builder for intent.
Do not nitpick style.
Prefer one strong finding over several weak ones.
Reviewer findings are suggestions for the builder to verify, not commands to obey.
```

When auditing a plan, ask for:

- feasibility risks;
- missing steps;
- unsafe sequencing;
- rollback gaps;
- scope creep;
- verification gaps;
- claims that need empirical checks.
- whether the provided test specifications cover the risky paths.

When auditing code changes, ask for:

- data integrity risks;
- auth/permission issues;
- hallucinated APIs or dependencies;
- fragile error handling;
- missing tests for changed behavior;
- scope creep beyond the requested change;
- tool or CLI behavior that must be verified empirically.
- whether the supplied test data or expected behavior would catch the reviewer's failure modes.

When auditing plan/implementation consistency, ask for:

- implementation mismatches;
- missing plan items;
- extra behavior not requested;
- accidental app-specific assumptions;
- tests that prove the plan was actually satisfied.

When auditing test specs/test data, ask for:

- missing edge cases;
- invalid assumptions in sample data;
- mismatches between expected behavior and implementation;
- validation commands that should be run before claiming success;
- tests that are too broad, too weak, or outside the user's scope.

Require output:

```text
# Summary

# Findings

## [severity: critical|high|medium] <title>

- **File/Section:** ...
- **What can go wrong:** ...
- **Why vulnerable:** ...
- **Impact:** ...
- **Recommendation:** ...

# Verdict

VERDICT: APPROVED
```

or:

```text
VERDICT: REVISE
```

The final line must be exactly one verdict line.

Append reviewer permissions:

```text
You may run commands to verify findings when useful.
Do not create, edit, delete, commit, or apply fixes to project files.
Prefer commands that do not mutate the working tree.
If verification would require mutation, report that limitation.
If a command unexpectedly changes files, stop and report it.
You are an auditor, not a contributor.
```

Append reviewer quality guard:

```text
If you cannot inspect the repository because of sandbox, auth, model, quota, or command failures, do not invent findings. Report the environmental limitation clearly and use VERDICT: REVISE.
```

Write the complete reviewer prompt body to:

```text
${TMP_ROOT}/advreview-body-${REVIEW_ID}.md
```

This file is the `PROMPT_BODY_PATH` passed to the runner. Do not rely on the runner to infer or rebuild the main prompt body.

Now that the prompt body exists, capture prompt-input hashes before dispatch:

```bash
for f in \
  "${TMP_ROOT}/advreview-body-${REVIEW_ID}.md" \
  "${TMP_ROOT}/advreview-plan-${REVIEW_ID}.md"
do
  [ -f "$f" ] && ${HASH_CMD} "$f"
done > "${TMP_ROOT}/advreview-inputs-pre-${REVIEW_ID}.sha"
```

This hash step must happen after writing `advreview-body-${REVIEW_ID}.md` and before dispatching the runner. Do not hash prompt inputs in Step 5, because the body file does not exist yet.

## Step 8: Dispatch Runner

Resolve the runner spec:

1. `skills/adversarial-reviewer-lite/references/runner.md` relative to this skill.
2. `${REPO_ROOT}/adversarial-reviewer-lite/skills/adversarial-reviewer-lite/references/runner.md`.
3. `~/.claude/skills/adversarial-reviewer-lite/references/runner.md`.

Dispatch a short-lived subagent synchronously in the foreground:

- `subagent_type`: `general-purpose`
- `model`: `sonnet`
- purpose: orchestration only; the reviewer model is still Codex CLI

Use:

```yaml
REVIEW_ID: <id>
REPO_ROOT: <absolute repo root>
OPERATION: initial
REVIEW_BACKEND: codex
REVIEWER_MODEL: <model>
REVIEWER_REASONING: <reasoning>
REVIEWER_SANDBOX: <sandbox>
REVIEWER_APPROVAL_POLICY: <on-request|never>
REVIEWER_APPROVALS_REVIEWER: <auto_review|unset>
TMP_ROOT: <temp directory outside repo>
PROMPT_BODY_PATH: ${TMP_ROOT}/advreview-body-<id>.md
RESULT_PATH: ${TMP_ROOT}/advreview-result-<id>.json
DIRTY_FILE_LIST_PATH: ${TMP_ROOT}/advreview-dirty-files-<id>.txt
```

The subagent reads `runner.md`, calls Codex CLI, validates the review file, classifies review quality, and writes a JSON result.

## Step 9: Mutation Snapshot After Review

Always run this step immediately after the runner returns, before consulting the result dispatch table and before any stop/abort path. Even a failed reviewer launch might have mutated files.

Read `RESULT_PATH` only after this mutation snapshot is captured.

Repeat the status and input hashes:

```bash
git -C "${REPO_ROOT}" status --porcelain > "${TMP_ROOT}/advreview-git-post-${REVIEW_ID}.txt"
for f in \
  "${TMP_ROOT}/advreview-body-${REVIEW_ID}.md" \
  "${TMP_ROOT}/advreview-plan-${REVIEW_ID}.md"
do
  [ -f "$f" ] && ${HASH_CMD} "$f"
done > "${TMP_ROOT}/advreview-inputs-post-${REVIEW_ID}.sha"
```

If dirty-file hashing was used, repeat it:

```bash
while read f; do
      h=$(git -C "${REPO_ROOT}" hash-object "$f" 2>/dev/null || true)
      printf '%s  %s\n' "$h" "$f"
    done < "${TMP_ROOT}/advreview-dirty-files-${REVIEW_ID}.txt" \
  > "${TMP_ROOT}/advreview-dirty-post-${REVIEW_ID}.sha"
```

Hard stop before showing reviewer output or applying fixes if any of these differ:

- `advreview-git-pre` vs `advreview-git-post`;
- `advreview-inputs-pre` vs `advreview-inputs-post`;
- `advreview-dirty-pre` vs `advreview-dirty-post`.

Message:

```text
Reviewer or runner mutated files during dispatch. Aborting before fixes. Inspect the Git diff manually.
```

## Step 10: Handle Runner Result

Read `RESULT_PATH`.

Use this dispatch table before showing or acting on review content:

| `result` | `review_quality` | Main action |
|---|---|---|
| `success` | `valid` | Continue to review display. |
| `success` | `unknown` | Warn that quality could not be classified, then continue cautiously. |
| `success` | `degraded_content` | Show warning and review file. Do not apply fixes automatically; treat as not verified unless the user explicitly wants to continue. |
| `success` | `degraded_environmental` | Surface environmental problem and stop. |
| `timeout` | any | Stop and report timeout. |
| `launch_failure` | any | Stop and report failure. |
| `infra_error` | any | Stop; leave temp files for diagnostics. |
| `input_error` | any | Stop; fix invocation/settings first. |

## Step 11: Show Review Verbatim

Before any fix, show the reviewer output verbatim:

```text
## Adversarial Reviewer Lite - Audit (reviewer: <model>)

<verbatim review>
```

Then provide a short operator summary in `OPERATOR_LANGUAGE`:

- `Status`: approved, revise, degraded, failed, or not verified.
- `Reviewer asked for`: concise list of findings.
- `Builder should do next`: audit sign-off, verify findings, apply accepted fixes, or stop.
- `Trust note`: reviewer output is not automatically trusted.

If verdict is `APPROVED`, continue to the terminal summary and stop.

If verdict is `REVISE` and audit mode is active, continue to audit report.

## Step 12: Audit Mode

For each finding, the builder independently classifies:

- `Confirmed`
- `Likely valid`
- `Disputed`
- `Out of scope`
- `Needs empirical verification`

Use the verification discipline from Step 13. Do not treat reviewer confidence as evidence.

Before touching code, present a beginner-readable report:

- executive summary;
- finding table;
- what is happening;
- what could go wrong;
- suggested fix;
- builder assessment;
- verification performed;
- verification still missing;
- terms explained once;
- what happens next.

Do not fix anything until the user explicitly approves. Audit mode is a report-and-signoff workflow first, a code-change workflow second.

Before generating an HTML artifact, ask:

```text
I can save this audit as an HTML report. This may create an audits/ folder and a .gitignore entry. OK to proceed? (yes / no / save elsewhere)
```

If yes, create a self-contained HTML report before any code changes. If no, keep the conversation report only. If save elsewhere, use the provided path and do not edit `.gitignore` when outside the repo.

Canonical HTML report structure:

- Use `examples/sample-audit-report.html` as the minimal canonical template.
- Keep all CSS inline.
- Include metadata: repo, mode, reviewer backend, reviewer model, reasoning, sandbox, approval mode, timestamp.
- Include a top-level status badge: approved, revise, not verified, or failed.
- Include severity badges and decision badges.
- Include an executive summary.
- Include one finding card per reviewer finding.
- Include builder decision for each finding: accepted, rejected, re-scoped, deferred, or needs verification.
- Include verification evidence or "not yet verified".
- Include glossary entries for beginner terms used in the report.
- Include an update log if fixes were applied after user approval.
- Do not include secrets, tokens, full private environment dumps, or unrelated repo content.

## Step 13: Finding Evaluation Matrix

Every reviewer finding must pass through this matrix before fixes are applied:

| # | Severity | Finding type | Verification method | Verified? | Action | User gate |
|---|---|---|---|---|---|---|
| 1 | critical/high/medium | structural/non-structural | reasoning/test/docs/inspection | yes/no/partial | accept/reject/re-scope/defer | needed/not needed |

Valid actions:

- `accept`: finding is valid; apply the smallest fix that addresses it.
- `reject`: finding is wrong, unsupported, duplicate, or out of scope; record the reason.
- `re-scope`: the concern is valid but the recommended fix is too broad; apply a narrower fix and explain why.
- `defer`: finding may be valid but cannot be safely handled in this pass; record the risk and next step.

Verification methods by finding type:

| Finding type | Minimum verification |
|---|---|
| Tool, CLI, config, package, or API claim | Empirical check when practical, such as running the command, checking installed docs, inspecting dependency files, or citing official docs. Do not accept tool-mechanic claims from reasoning alone. |
| Runtime behavior | Test, reproduction, log inspection, or code-path tracing. If not runnable, mark as not verified. |
| Data or migration risk | Inspect schemas, migrations, writes, deletes, uniqueness, rollback path, and test coverage. |
| Auth, permissions, or security | Name the concrete threat model and data boundary; verify with code paths or configuration. |
| Architecture or sequencing | Inspect affected call graph, state transitions, and failure modes. |
| Scope creep | Compare against the user's request or plan. Extra behavior is not automatically acceptable just because it is useful. |
| Style or readability | Compare against existing repo conventions. Do not spend review effort on style-only issues unless they hide correctness risk. |

Receiving-feedback discipline:

- Read the full finding before agreeing.
- Restate the claim internally as a falsifiable statement.
- Verify tool-mechanic claims empirically when practical.
- Push back when the reviewer is wrong.
- Do not performatively agree with the reviewer.
- Do not expand scope just because the reviewer suggested a larger refactor.
- Prefer minimal, targeted fixes over broad rewrites.
- If the reviewer contradicts an explicit user requirement, pause and ask the user.

Structural classification:

Treat a finding as structural when it changes or questions:

- invocation grammar;
- machine-readable output literals;
- audit workflow;
- terminal-state behavior;
- reviewer dispatch behavior;
- sandbox, approvals, privacy, or mutation guarantees;
- public configuration contract;
- schemas, migrations, data writes, or destructive operations;
- broad architecture;
- any item where the blast radius is uncertain.

Treat as non-structural when it is limited to:

- wording;
- documentation clarity;
- examples;
- narrow heuristics;
- local bug fixes with contained blast radius;
- cosmetic report formatting.

Structural gate:

- If a structural fix is needed and the operator is reachable, pause once with a short explanation before applying it.
- If the user already explicitly requested autonomous fixing of all issues, proceed but record that a structural change was made.
- Never hide structural changes inside a generic "minor fix" summary.

## Step 14: Terminal Operator Summary

At every terminal state, give a synthesized summary in `OPERATOR_LANGUAGE`.

Required fields:

- `Final status`: approved, revise, failed, not verified, or stopped by user.
- `What changed`: files or sections changed by the builder, or "nothing changed".
- `Reviewer findings`: accepted, rejected, re-scoped, deferred.
- `Verification`: commands run and results, or why not run.
- `Structural changes`: list any structural changes or say none.
- `Remaining risks`: concise, honest list.
- `Next step`: one practical action for the user.

For audit mode, explicitly state whether the user has signed off on fixes. If not, say no fixes were applied.

## Step 15: Cleanup

On approved, stopped-by-user, or not-verified terminal states, remove only the explicit temp files created by this review id:

```bash
rm -f \
  "${TMP_ROOT}/advreview-body-${REVIEW_ID}.md" \
  "${TMP_ROOT}/advreview-plan-${REVIEW_ID}.md" \
  "${TMP_ROOT}/advreview-prompt-${REVIEW_ID}.md" \
  "${TMP_ROOT}/advreview-review-${REVIEW_ID}.md" \
  "${TMP_ROOT}/advreview-stdout-${REVIEW_ID}.jsonl" \
  "${TMP_ROOT}/advreview-stderr-${REVIEW_ID}.txt" \
  "${TMP_ROOT}/advreview-result-${REVIEW_ID}.json" \
  "${TMP_ROOT}/advreview-preflight-${REVIEW_ID}.txt" \
  "${TMP_ROOT}/advreview-preflight-err-${REVIEW_ID}.txt" \
  "${TMP_ROOT}/advreview-git-pre-${REVIEW_ID}.txt" \
  "${TMP_ROOT}/advreview-git-post-${REVIEW_ID}.txt" \
  "${TMP_ROOT}/advreview-inputs-pre-${REVIEW_ID}.sha" \
  "${TMP_ROOT}/advreview-inputs-post-${REVIEW_ID}.sha" \
  "${TMP_ROOT}/advreview-dirty-files-${REVIEW_ID}.txt" \
  "${TMP_ROOT}/advreview-dirty-pre-${REVIEW_ID}.sha" \
  "${TMP_ROOT}/advreview-dirty-post-${REVIEW_ID}.sha"
```

On launch failure, infrastructure failure, or mutation-detected abort, leave temp files for diagnostics and tell the user where they are.

## Rules

- Show reviewer output verbatim before fixes.
- Reviewer findings are suggestions to verify, not commands to obey.
- Audit mode requires user sign-off before fixes.
- Audit mode must present the validated report and HTML-report option before touching code.
- Test specs and test data should be passed to the reviewer when available, exhaustive but focused on the requested scope.
- Tool-mechanic findings need empirical verification when practical.
- Structural fixes need an explicit gate or an explicit autonomous-fix instruction.
- Windows defaults to `danger-full-access` only because `bwrap` usually fails there.
- Do not push, commit, or publish as part of this skill.
- Multi-model jury is roadmap only in v1.

