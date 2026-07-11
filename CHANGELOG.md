# Changelog

## Unreleased

### Added
- **Human-review floor.** An `APPROVED` verdict is no longer terminal when the diff
  touches floor categories: auth/permissions, money/billing, migrations/destructive
  data operations, secrets, or regulatory-tagged paths. Step 4 detects the categories
  (path patterns + destructive-diff content patterns + optional per-repo
  `.advreview-floor` regex file), and Step 11 requires the user to review the diff and
  reply `reviewed-ok` (or raise a concern, which enters the normal REVISE path) before
  the audit completes. Rationale: a clean second-model approval on a billing change
  should produce more human scrutiny, not less — the approval previously read as
  permission to skip it.
- **Rubric input (`rubric:<path>`).** Injects a domain checklist into the reviewer
  prompt; the reviewer must report `PASS`/`FAIL`/`UNVERIFIABLE` per item with evidence
  in a `# Rubric Results` section, and any `FAIL` forces `VERDICT: REVISE`. The runner
  validates the section's presence (`RUBRIC_PRESENT` input), counts failures into
  triage (`rubric_present`, `rubric_fail_count`), and classifies a review that ignores
  the rubric — or approves alongside a `FAIL` — as `degraded_content`.
- **Strict mode (`strict`).** One flag for high-consequence repos: requires
  `rubric:<path>` (stops with guidance if missing), floor-gates every change regardless
  of category, and disables autonomous fixing — prior "fix whatever it finds"
  authorizations are void while strict is active, including the Step 13 structural-gate
  autonomous exception.
- **Contract hardening.** Runner R7 now classifies internally inconsistent reviews
  (`FAIL` rubric line with `VERDICT: APPROVED`; `REVISE` with a zero-revision scorecard)
  as `degraded_content` instead of passing them through as valid.
- Terminal summary (Step 14) gains `Floor gate` and `Rubric` fields.

### Fixed
- **Codex "Not inside a trusted directory" misdiagnosed as a model outage.**
  `codex exec` refuses to run outside a git repository unless `--skip-git-repo-check`
  is passed. The model **preflight** (SKILL.md Step 6) and the **self-test dispatch**
  (SKILL.md Step 0 / ST-6) previously ran `codex exec` without it and from the current
  working directory. When that directory was not a git repo, every model in the
  fallback chain failed the same way, and the skill reported *"No reviewer model is
  available — check auth/quota/network"* — pointing users at the wrong problem entirely
  (auth and models were fine).

  Both of those dispatches send only a dummy probe (`MODEL_OK` / a fixed verdict) with
  **no repository content**, so Codex's trusted-directory guard adds no protection there.
  They now pass `--skip-git-repo-check`. The **real review dispatch** is unchanged and
  keeps full git-based mutation safety by running with `-C "${REPO_ROOT}"`
  (references/runner.md, Step R4).

### Added
- Explicit detection of the trusted-directory refusal. Step 6 and ST-6 now distinguish
  an *environmental block* (trusted-directory / sandbox / auth) from a genuine
  *model-availability* failure and print the correct remedy instead of exhausting the
  fallback chain with a misleading message.
- `runner.md` R7 lists the `not inside a trusted directory` / `--skip-git-repo-check`
  refusal as a `degraded_environmental` signal so the runner reports it as an
  environment problem rather than inventing findings.
- A troubleshooting-table entry for the "all models unavailable but auth is healthy"
  symptom.

### Notes
- The floor/rubric additions were stress-tested before release: 42 executable
  positive/negative cases against the floor-detection and rubric-validation grep
  patterns, plus a fresh-eyes adversarial consistency review of SKILL.md + runner.md
  that surfaced and fixed 8 defects pre-commit (branch-diff floor blind spot, a dead
  `FLOOR_GATE_ALL` variable, strict mode blocking selftest, unenforced rubric coverage,
  missing R3 triage fields, missing HTML report wiring, `rm -fr`/diff-header regex
  gaps, and the all-UNVERIFIABLE-approval hole).
- Surfaced by first-run dogfooding on Windows / Git Bash: Codex CLI 0.133.0, `gpt-5.5`,
  auth healthy, but the self-test's model dispatch failed for all four models solely
  because the working directory was not a git repository.
