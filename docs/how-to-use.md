# How To Use Adversarial Reviewer Lite

Adversarial Reviewer Lite is distributed as a Claude Code skill. The repo-level README is for humans. The `SKILL.md` file is for Claude Code. The runner reference is for the short-lived orchestration subagent that calls Codex CLI.

Claude Code skills are folders with a required `SKILL.md` file. The folder name becomes the slash command, and the description tells Claude when the skill is relevant. See the official docs: https://code.claude.com/docs/en/skills

## Install

Clone the public repo wherever you keep tools:

```bash
git clone https://github.com/razaumair2203-ux/adversarial-reviewer-lite.git
```

Copy the skill folder into your personal Claude Code skills directory:

```bash
bash scripts/install.sh
```

On Windows PowerShell, the same idea is:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1
```

If PowerShell scripts are blocked by policy, copy the skill folder manually:

```powershell
$dest = "$env:USERPROFILE\.claude\skills\adversarial-reviewer-lite"
if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
Copy-Item -Recurse "skills\adversarial-reviewer-lite" $dest
```

Claude Code uses the installed folder name as the slash command. If you want the command to be `/adversarial-reviewer-lite audit`, install the folder as:

```text
~/.claude/skills/adversarial-reviewer-lite
```

## Prerequisites

Install and authenticate Codex CLI:

```bash
npm install -g @openai/codex
codex --version
codex login
codex doctor --summary
```

Make sure the shell Claude Code uses can run the local tools required by the skill:

```bash
git --version
codex --version
timeout --version
grep --version
tail --version
sort --version
sha256sum --version || shasum --version
```

On Windows, Git Bash or WSL is required for running audits because the skill uses POSIX commands (`timeout`, `grep`, `tail`, `sort`, `sha256sum`) and bash syntax throughout. The skill will stop with an error if the shell is not bash-compatible.

If any prerequisite is missing, the skill should stop before review and show a setup-needed message. It should not send repo context to Codex, dispatch the runner, or install tools silently. Install the missing tools, reopen Claude Code if `PATH` changed, then run `/adversarial-reviewer-lite audit` again.

The default reviewer model is `gpt-5.5`. If your Codex account does not have that model, invoke the skill with a model you can use:

```text
/adversarial-reviewer-lite audit reviewer:<your-model>
```

If you do not have Codex CLI yet, see [no-codex-yet.md](no-codex-yet.md) for the manual trial prompt and setup path.

## Invoke

From inside a Git repo in Claude Code:

```text
/adversarial-reviewer-lite audit
```

Use it deliberately. Claude Code may not reliably prompt you to run this skill automatically. A good habit is:

```text
Build with Claude. Before you trust the change, run:
/adversarial-reviewer-lite audit
```

With focused test expectations:

```text
/adversarial-reviewer-lite audit test-spec:docs/change-tests.md
```

With sample edge-case data:

```text
/adversarial-reviewer-lite audit test-data:fixtures/change-cases.json
```

With both:

```text
/adversarial-reviewer-lite audit test-spec:docs/change-tests.md test-data:fixtures/change-cases.json
```

Keep the test bundle exhaustive for the requested change but focused. Include expected behavior, known edge cases, validation commands, fixtures, and scenarios that must remain out of scope.

## When To Run It

Run the audit after Claude Code:

- writes or edits code you plan to keep;
- proposes a multi-step plan;
- changes data writes, auth, permissions, migrations, background jobs, billing, or file deletion;
- claims a command, package, API, or CLI behavior that might be hallucinated;
- makes a cross-file refactor;
- says a fix is complete but the verification feels thin.

Skip it for very small wording, typo, or cosmetic-only edits.

## Why Use The Skill Instead Of A Manual Review Window?

A manual second-agent review can help, but it relies on the user remembering every safety step. The skill packages the workflow:

- privacy notice before repo context is sent to Codex;
- model preflight;
- Windows sandbox handling;
- dirty-file mutation checks;
- strict reviewer output format;
- builder-side accept/reject/re-scope/defer decisions;
- report-before-code sign-off;
- optional HTML audit artifact.

The skill is best when you want repeatability. A manual second window is fine for quick informal review, but it will not automatically enforce this workflow.

## What The User Sees

The user should see:

- the raw reviewer output;
- a builder assessment of each finding;
- verification performed or still missing;
- a report before code is touched;
- an optional HTML report prompt;
- a clear sign-off request before fixes.

## Confidence Checklist

Before accepting fixes, check:

- the raw reviewer output was shown;
- each finding has a builder decision;
- weak or wrong findings were rejected or re-scoped;
- tool/API/package claims were empirically checked when practical;
- the report was shown before code was touched;
- you explicitly approved any fixes.

## Optional Reminders

Project-level Claude reminder:

```bash
cat snippets/claude-md-reminder.md >> CLAUDE.md
```

Git post-commit reminder:

```bash
cp snippets/post-commit-reminder.sample .git/hooks/post-commit
chmod +x .git/hooks/post-commit
```

Both reminders are passive. They should suggest `/adversarial-reviewer-lite audit`; they should not run it automatically.

## If It Does Not Start

Check:

- the skill is installed at `~/.claude/skills/adversarial-reviewer-lite`;
- `SKILL.md` is directly inside that folder;
- Claude Code was restarted after installation;
- Codex CLI is installed and logged in;
- you invoked `/adversarial-reviewer-lite audit`, not just a natural-language request.

For more symptoms and fixes, see [troubleshooting.md](troubleshooting.md).

## HTML Audit Report

The HTML report is optional and consent-gated. The canonical minimal format is:

```text
skills/adversarial-reviewer-lite/references/sample-audit-report.html
```

The source repository also keeps a public preview copy at `examples/sample-audit-report.html`.

For a quick visual map of the report sections, see:

```text
docs/assets/audit-report-anatomy.svg
```

The report should include:

- metadata: repo, reviewer backend, model, reasoning, sandbox, approval mode, timestamp;
- top-level status badge;
- severity and decision badges;
- executive summary;
- one finding card per reviewer finding;
- builder decision and verification evidence;
- beginner glossary;
- update log if fixes are later approved and applied.

Do not include secrets, full environment dumps, unrelated file contents, or private tokens in the report.
