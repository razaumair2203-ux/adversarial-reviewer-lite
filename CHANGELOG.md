# Changelog

## Unreleased

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
- Surfaced by first-run dogfooding on Windows / Git Bash: Codex CLI 0.133.0, `gpt-5.5`,
  auth healthy, but the self-test's model dispatch failed for all four models solely
  because the working directory was not a git repository.
