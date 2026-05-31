# Troubleshooting

| Symptom | Likely Cause | Fix |
|---|---|---|
| `/adversarial-reviewer-lite audit` is not available | Skill folder is missing or Claude Code has not reloaded skills | Confirm `~/.claude/skills/adversarial-reviewer-lite/SKILL.md` exists, then restart Claude Code. |
| Skill starts but says Codex is missing | Codex CLI is not installed or not on `PATH` | Run `npm install -g @openai/codex`, then reopen Claude Code and run `codex --version`. |
| Codex health check fails | Not logged in, bad config, proxy/network issue, or broken Codex install | Run `codex login` and `codex doctor --summary` in the same shell Claude Code uses. |
| Reviewer model unavailable | Your Codex account cannot use the default model | Run `/adversarial-reviewer-lite audit reviewer:<model-you-have>`. |
| Windows sandbox fails with `bwrap` | Linux sandbox tooling is unavailable on Windows | Use the default Windows behavior first. Read `docs/windows-sandbox.md` before overriding sandbox settings. |
| Missing `timeout`, `grep`, `tail`, `sort`, or `sha256sum` | Shell lacks POSIX tooling | Use Git Bash or WSL on Windows. Reopen Claude Code after changing `PATH`. |
| Output is mostly setup or sandbox errors | Reviewer did not inspect the repo meaningfully | Treat the audit as not verified. Fix setup and rerun. |
| Reviewer gives generic advice | Scope was too broad or context was weak | Rerun with focused files, test specs, or sample data. |
| Builder wants to apply a large refactor from reviewer feedback | Reviewer recommendation may be over-scoped | Use `re-scope` or ask the user before structural changes. |
| HTML report contains sensitive details | Report scope included too much context | Do not publish the report. Regenerate with secrets removed and narrower scope. |
