# Public Release Checklist

## Repository Metadata

Suggested repo name:

```text
adversarial-reviewer-lite
```

Suggested GitHub description:

```text
Claude Code skill for Windows-friendly adversarial AI code review using Codex CLI as an independent reviewer.
```

Suggested topics:

```text
claude-code
claude-code-skill
ai-code-review
adversarial-review
codex-cli
agentic-coding
windows-dev
llm-tools
code-review
ai-safety
```

## Before Publishing

- Confirm `/adversarial-reviewer-lite audit` appears in README and docs.
- Run `scripts/install.sh` from Git Bash or macOS/Linux.
- Run `scripts/install.ps1` from PowerShell.
- Confirm `~/.claude/skills/adversarial-reviewer-lite/SKILL.md` exists after install.
- Confirm the README preview image renders.
- Confirm no private paths, repo URLs, API keys, tokens, or customer data are present.
- Confirm sample audit output and HTML report are generic.
- Confirm no GitHub push includes local `audits/`, `tmp/`, or `*.local.html`.

## Launch Targets

- GitHub README and repo topics.
- r/ClaudeAI.
- r/ChatGPTCoding.
- Hacker News `Show HN`.
- X/LinkedIn short demo post.
- Optional blog post.

## Launch Message Angle

```text
Build with Claude. Before you trust it, make Codex review it.
```

Keep claims modest:

- reduces blind spots;
- does not prove correctness;
- reviewer findings still need verification;
- Windows support is pragmatic, not a security boundary.
