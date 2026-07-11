# Codex Adversarial Review - Lite Codex Runner

This runner is intentionally backend-specific. Codex Adversarial Review - Lite v1 is packaged for Claude Code as builder and Codex CLI as reviewer; the generic `builder` and `reviewer` terms are kept only so future versions can stay portable.

The main skill dispatches this runner in a short-lived subagent. The runner launches one Codex CLI review, validates the result, classifies review quality, and writes a JSON summary. It does not apply fixes.

## Input Contract

```yaml
REVIEW_ID: <string>
REPO_ROOT: <absolute path>
OPERATION: initial
REVIEW_BACKEND: codex
REVIEWER_MODEL: <e.g. gpt-5.5>
REVIEWER_REASONING: low | medium | high | xhigh
REVIEWER_SANDBOX: read-only | workspace-write | danger-full-access | inherit
REVIEWER_APPROVAL_POLICY: on-request | never
REVIEWER_APPROVALS_REVIEWER: auto_review | unset
TMP_ROOT: <temp directory outside repo>
PROMPT_BODY_PATH: <absolute path>
RESULT_PATH: ${TMP_ROOT}/advreview-result-<REVIEW_ID>.json
DIRTY_FILE_LIST_PATH: ${TMP_ROOT}/advreview-dirty-files-<REVIEW_ID>.txt
RUBRIC_PRESENT: true | false
```

`RUBRIC_PRESENT` is optional; treat a missing value as `false`. When `true`, the prompt body already contains the rubric and the review must contain a `# Rubric Results` section (see R6).

If `REVIEW_BACKEND` is not `codex`, write an `input_error` result.

## Output Contract

Write this JSON to `RESULT_PATH`:

```json
{
  "result": "success",
  "verdict": "APPROVED",
  "review_file": "${TMP_ROOT}/advreview-review-<REVIEW_ID>.md",
  "reviewer_session_id": null,
  "errors": null,
  "review_quality": "valid",
  "triage": {
    "finding_count": 0,
    "max_severity": "none",
    "needs_builder_judgment": false,
    "rubric_present": false,
    "rubric_fail_count": 0
  }
}
```

`rubric_present` mirrors the `RUBRIC_PRESENT` input. `rubric_fail_count` is the number of `- [FAIL]` lines in the review; always `0` when no rubric was passed.

Allowed values:

- `result`: `success`, `launch_failure`, `timeout`, `infra_error`, `input_error`
- `verdict`: `APPROVED`, `REVISE`, or `null`
- `review_quality`: `valid`, `degraded_environmental`, `degraded_content`, `unknown`

Final response to main must be exactly:

```text
RUNNER_RESULT_AT: <RESULT_PATH>
```

## Step R1: Validate Inputs

Required values:

- `REVIEW_ID`
- `REPO_ROOT`
- `OPERATION`
- `REVIEW_BACKEND`
- `REVIEWER_MODEL`
- `REVIEWER_REASONING`
- `REVIEWER_SANDBOX`
- `TMP_ROOT`
- `PROMPT_BODY_PATH`
- `RESULT_PATH`

Validate:

- `REVIEW_BACKEND=codex`
- `OPERATION=initial`
- `REVIEW_ID` matches `^[0-9]+-[0-9]{8}$`
- `PROMPT_BODY_PATH` exists and is non-empty
- `REPO_ROOT` exists
- `TMP_ROOT` exists or can be created
- `DIRTY_FILE_LIST_PATH`, when present, is outside the repo and readable
- `codex` exists on `PATH`
- `timeout` exists on `PATH`
- `grep` exists on `PATH`
- `tail` exists on `PATH`
- `cat` exists on `PATH`
- `sort` exists on `PATH` when the main skill passes sorted dirty-file lists through this runner environment

If validation fails, write `input_error` with a clear message naming the missing dependency or invalid input. Do not attempt to launch Codex.

## Step R2: Build Prompt File

Generate a fresh 6-digit attempt id.

Write:

```text
${TMP_ROOT}/advreview-prompt-${REVIEW_ID}.md
```

First line:

```text
<!-- ADVREVIEW-LITE-SESSION: ${REVIEW_ID}-${ATTEMPT_ID} -->
```

Then append the prompt body from `PROMPT_BODY_PATH`.

If `DIRTY_FILE_LIST_PATH` exists and is non-empty, append this warning block to the prompt:

```text
The following tracked files were already dirty before review dispatch.
Do not edit, format, or otherwise mutate these files.
If you believe one of them must be inspected, inspect read-only and report findings only.

<dirty file list>
```

## Step R3: Sandbox Preflight

Run only when:

- `OPERATION=initial`;
- `REVIEWER_SANDBOX` is `read-only` or `workspace-write`.

Probe:

```bash
bwrap --dev-bind / / --unshare-net /bin/echo ok 2>&1
```

If it fails, write:

```json
{
  "result": "success",
  "verdict": "REVISE",
  "review_file": "${TMP_ROOT}/advreview-stderr-<REVIEW_ID>.txt",
  "reviewer_session_id": null,
  "errors": "Sandbox preflight failed; bwrap is unavailable or unusable.",
  "review_quality": "degraded_environmental",
  "triage": {
    "finding_count": 0,
    "max_severity": "none",
    "needs_builder_judgment": false,
    "rubric_present": false,
    "rubric_fail_count": 0
  }
}
```

(Set `rubric_present` to the actual `RUBRIC_PRESENT` input; `rubric_fail_count` stays `0` because no review ran.)

Main will surface the sandbox diagnostic and abort or retry with an explicitly chosen safer/fallback mode. The runner must not silently switch to `danger-full-access`.

Skip preflight for:

- `danger-full-access`;
- `inherit`.

## Step R4: Build Codex Command

Use a 600 second timeout for reviewer execution.

**Important runtime notes:**
- `-o file` (`--output-last-message`) captures the agent's final response to a file. Use this for the review output.
- `--json` prints JSONL events to stdout (session metadata, tool calls, etc.). This is separate from `-o` and can be used alongside it for diagnostics.
- `codex exec` is non-interactive — always pass `-c approval_policy=never` to prevent the process from hanging on approval prompts that will never be answered. The sandbox flag (`-s`) is the actual security boundary.
- Never use `--dangerously-bypass-approvals-and-sandbox` — it removes all sandbox protection. Use `-s <mode>` + `-c approval_policy=never` instead.

Base command:

```bash
cat "${TMP_ROOT}/advreview-prompt-${REVIEW_ID}.md" | \
  timeout 600 codex exec -m ${REVIEWER_MODEL} \
    -s ${REVIEWER_SANDBOX} \
    -c approval_policy=never \
    -c model_reasoning_effort=${REVIEWER_REASONING} \
    -C "${REPO_ROOT}" \
    -o "${TMP_ROOT}/advreview-review-${REVIEW_ID}.md" \
    - \
  2>"${TMP_ROOT}/advreview-stderr-${REVIEW_ID}.txt"
```

The prompt file is piped via stdin (the `-` argument tells `codex exec` to read from stdin). The `-o` flag writes the agent's last message to the review file. Stderr is captured separately for diagnostics. If `REVIEWER_SANDBOX=inherit`, omit the `-s` flag.

## Step R5: Retry Policy

Retry once with a fresh attempt id only when:

- Codex exits non-zero without a clear input/configuration error;
- the review file is missing or empty;
- the review file lacks a final verdict line;
- stdout/stderr suggests transient CLI failure.

Do not retry when:

- `REVIEW_BACKEND` is invalid;
- `PROMPT_BODY_PATH` is missing;
- auth, quota, or model-not-found errors are clear;
- sandbox preflight failed;
- timeout already happened twice.

If Codex times out twice, write `timeout`.

If both attempts fail validation, write `launch_failure`.

## Step R6: Validate Review

The review file must:

- exist;
- be non-empty;
- contain exactly one final verdict line starting with `VERDICT: APPROVED` or `VERDICT: REVISE`;
- when the verdict is `REVISE`, the verdict line should include a scorecard summary (e.g. `VERDICT: REVISE — 8 passing, 2 need revision (1 high, 1 medium)`);
- contain at least one `[severity: critical|high|medium]` tag when verdict is `REVISE`, unless the body is classified as `degraded_environmental`;
- when `RUBRIC_PRESENT=true`, contain a `# Rubric Results` section with at least one result line matching `^- \[(PASS|FAIL|UNVERIFIABLE)\]`.

Rubric check when `RUBRIC_PRESENT=true`:

```bash
grep -n -E '^#+ Rubric Results' "${TMP_ROOT}/advreview-review-${REVIEW_ID}.md"
grep -c -E '^- \[(PASS|FAIL|UNVERIFIABLE)\]' "${TMP_ROOT}/advreview-review-${REVIEW_ID}.md"
grep -c -E '^- \[FAIL\]' "${TMP_ROOT}/advreview-review-${REVIEW_ID}.md" || true
```

A missing rubric section counts as a validation failure for the R5 retry policy (the reviewer ignored a required output section). If the retry also omits it, do not write `launch_failure` — the review may still be useful; classify it `degraded_content` in R7 so main treats it as not verified.

Recommended checks:

```bash
if command -v rg >/dev/null 2>&1; then
  tail -n 5 "${TMP_ROOT}/advreview-review-${REVIEW_ID}.md" | rg '^VERDICT: (APPROVED|REVISE)'
  rg -n -i '\[severity:\s*(critical|high|medium)\]' "${TMP_ROOT}/advreview-review-${REVIEW_ID}.md"
else
  tail -n 5 "${TMP_ROOT}/advreview-review-${REVIEW_ID}.md" | grep -E '^VERDICT: (APPROVED|REVISE)'
  grep -n -i -E '\[severity:[[:space:]]*(critical|high|medium)\]' "${TMP_ROOT}/advreview-review-${REVIEW_ID}.md"
fi
```

Extract `reviewer_session_id` from Codex JSONL when available for diagnostics. If unavailable, set it to null.

## Step R7: Classify Review Quality

Classify as `degraded_environmental` when the review body is mostly environment or tool failure text rather than a real review.

Signals include:

- sandbox or `bwrap` failure;
- auth, login, token, quota, rate-limit, or model-not-found errors;
- trust/repository confirmation prompt that cannot be answered;
- `not inside a trusted directory` / `--skip-git-repo-check` refusal (the dispatch should run with `-C "${REPO_ROOT}"`; if this still appears, `REPO_ROOT` is not a git repo — report it as environmental, do not invent findings);
- "command not found" for required tools;
- no access to repository content;
- repeated timeout or cancellation text;
- a verdict included only around failure diagnostics.

Classify as `degraded_content` when:

- the review has verdict markers but no actionable findings;
- findings are generic advice not tied to files, sections, commands, or plan details;
- severity tags exist but the body does not explain concrete impact;
- the reviewer mostly praises or summarizes rather than audits;
- `RUBRIC_PRESENT=true` but the review has no `# Rubric Results` section or no per-item result lines (the reviewer ignored the rubric, so the review is not checkable against it);
- `RUBRIC_PRESENT=true` with `VERDICT: APPROVED` and zero `- [PASS]` lines — an approval where nothing on the checklist was actually verified;
- the review is internally inconsistent: a `- [FAIL]` rubric line together with `VERDICT: APPROVED`, or a `REVISE` verdict whose scorecard claims zero items need revision.

Classify as `valid` when:

- the review inspected the requested scope;
- findings, if any, are concrete enough for builder verification;
- verdict is well-formed;
- environmental errors are absent or clearly non-blocking.

Use `unknown` only when the runner cannot confidently classify quality.

## Step R8: Triage

Count severity tags:

```bash
if command -v rg >/dev/null 2>&1; then
  rg -n -i '\[severity:\s*(critical|high|medium)\]' "${TMP_ROOT}/advreview-review-${REVIEW_ID}.md"
else
  grep -n -i -E '\[severity:[[:space:]]*(critical|high|medium)\]' "${TMP_ROOT}/advreview-review-${REVIEW_ID}.md"
fi
```

When `RUBRIC_PRESENT=true`, also count rubric results:

```bash
grep -c -E '^- \[FAIL\]' "${TMP_ROOT}/advreview-review-${REVIEW_ID}.md" || true
```

Set:

- `finding_count`
- `max_severity`: `critical`, `high`, `medium`, or `none`
- `needs_builder_judgment`: true for `REVISE`, `degraded_content`, or `unknown`
- `rubric_present`: mirror of the `RUBRIC_PRESENT` input
- `rubric_fail_count`: number of `- [FAIL]` lines; `0` when no rubric was passed

`degraded_environmental` always needs main-thread handling before builder fixes.

## Step R9: Write Result

Write the JSON result to `RESULT_PATH`.

Then return:

```text
RUNNER_RESULT_AT: <RESULT_PATH>
```

## Claude Code Runtime Notes

This runner executes as a Claude Code subagent. Each Bash tool call is an isolated `bash -c` invocation — shell variables do not persist between calls. The runner must:

- Redeclare `REVIEW_ID`, `TMP_ROOT`, `REPO_ROOT`, and all other state variables in every Bash call that references them.
- Use Claude Code's Write tool (not bash heredocs) for writing multi-line content that contains markdown, backticks, or shell metacharacters.
- On Windows/Git Bash, use the bash `/tmp/...` path for Bash tool calls and the platform-native path (e.g., `C:\Users\...\Temp\...`) for Write/Read tool calls if needed.
- Verify hash and output files are non-empty after writing them — empty files indicate variable expansion failure.

## Runner Rules

- Do not edit project files.
- Do not apply fixes.
- Do not start multiple review rounds.
- Do not delete temp files; main owns cleanup.
- Do not include the review text inside the JSON.
- Do not silently relax sandbox or approval policy.
- Treat the dirty-file warning list as read-only protected user work.
- Report environmental failures as `degraded_environmental`, not invented findings.

