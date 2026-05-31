# LinkedIn Launch Post

AI coding agents are getting good enough that many non-technical people are starting to use them for real work.

That is exciting. It is also where things get risky.

The problem is not that tools like Claude Code or Codex are "bad." The problem is that coding agents can sound confident while still:

- inventing APIs or package behavior;
- expanding the task beyond what you asked for;
- saying tests passed when the verification was thin;
- missing data-loss, auth, migration, or file-deletion risks;
- agreeing too quickly with their own plan.

If you are new to agentic coding, the hardest part is knowing when to trust the answer.

So I built **Adversarial Reviewer Lite**.

It is a lightweight Claude Code skill that lets you build with Claude, then ask Codex to independently review the work before you accept it.

The flow is simple:

1. Claude Code builds or plans the change.
2. You run `/adversarial-reviewer-lite audit`.
3. Codex reviews the plan/code as an independent reviewer.
4. Claude shows the raw reviewer output.
5. Claude validates each finding instead of blindly obeying it.
6. You get a readable audit report before any code is changed.
7. Fixes only happen after you sign off.

This is especially focused on Windows users and early adopters of AI coding agents. A lot of agent tooling quietly assumes Linux-style sandboxing. On Windows, Codex sandbox behavior can hit `bwrap`/bubblewrap limitations, so this project documents the tradeoff clearly and adds mutation checks, privacy warnings, approval controls, and report-before-code discipline.

The idea is not "AI reviews AI, therefore it is correct."

The idea is better:

Use two different agents with different failure modes, then force the builder to verify the reviewer before touching code.

That matters because same-agent self-review often shares the same assumptions as the original answer. Independent review creates a second failure surface. It can catch hallucinated APIs, weak tests, scope creep, unsafe implementation paths, and overconfident summaries.

This will not replace human judgment. It is not a security boundary. It does not prove the code is safe.

But it gives beginners and solo builders a repeatable safety habit:

**Build with Claude. Before you trust it, make Codex review it.**

The first release is intentionally narrow:

- Claude Code as builder;
- Codex CLI as reviewer;
- one-pass audit mode;
- Windows-aware defaults;
- optional HTML audit report;
- no automatic code changes before user sign-off.

I made it public because I think more people need small, understandable workflows for reducing hallucination and scope creep in AI-assisted coding.

Repo:

https://github.com/razaumair2203-ux/adversarial-reviewer-lite

Suggested image attachment:

docs/assets/audit-report-preview.jpg

If you are experimenting with Claude Code, Codex, or agentic coding workflows, I would love feedback.

What would make an AI-generated code change feel trustworthy enough for you to ship?

#ClaudeCode #Codex #AICoding #AgenticAI #CodeReview #AISafety #WindowsDev
