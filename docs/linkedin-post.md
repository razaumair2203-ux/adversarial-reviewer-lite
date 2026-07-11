# LinkedIn Launch Post

AI hallucinates. There is no denying it.

You might not notice it during daily usage — quick scripts, small automations, throwaway prototypes. But the moment you try to make AI build something deploy-worthy — a product, an API, something users depend on — you start to notice where it falters.

It invents APIs that do not exist. It expands scope beyond what you asked. It says "tests pass" when the verification was shallow. It misses data-loss risks, auth gaps, and edge cases that would cost you real hours to debug later.

This hits hardest for people jumping on the vibe coding wave without a traditional software background. You are building real things, but you do not always know which AI-generated claim to trust and which one to verify.

After studying contemporary research and existing solutions, I built **Codex Adversarial Review - Lite** — a Claude Code skill that has your code reviewed adversarially by a separate, independent agent before you trust it.

**Why a separate agent? Why not just ask the same AI to review itself?**

Research supports this. Huang et al. found that LLMs can struggle to self-correct reasoning without external feedback — and can even degrade correct answers when asked to review themselves (https://arxiv.org/abs/2310.01798). A 2024 critical survey in TACL confirmed that prompted self-correction is unreliable without external signals (https://aclanthology.org/2024.tacl-1.78/). And multi-agent debate research shows that independent model perspectives can measurably reduce hallucinations (https://arxiv.org/abs/2305.14325).

The short version: asking the same model to critique itself often preserves the same blind spots. A different agent brings different priors, different failure modes, and a different perspective.

**This does not promise magic.** But it adds an impactful guardrail against your coding agent hallucinating out of control.

**How it actually works — and why it is not circular:**

This is a Claude Code skill — a structured contract between two agents. For v1, Claude Code is the builder and Codex CLI is the reviewer and QA.

1. The builder builds your code or plan.
2. The builder helps you define test specifications — what should work, what should not, what edge cases matter.
3. You invoke `/codex-adversarial-review-lite audit`.
4. The builder passes the code, plan, and test specification contract to the independent reviewer.
5. The reviewer (Codex) reviews adversarially. It does not touch any of your files. It passes findings back to the builder.
6. The builder assesses and validates each finding — it does not blindly obey the reviewer. It pushes back when findings are wrong. Still does not touch any artifact.
7. The builder presents an easy-to-read HTML report: what the issues are, their impact, and recommended next steps — explained in plain language.
8. Nothing changes until you sign off.

The builder does not silently invoke the reviewer. It is user-initiated, user-controlled, and user-approved at every step. It is essentially what you are already doing when you ask a second opinion — but more systematic, more efficient, and with less rework.

**Specifically tailored for product builders without a deep software background.** After much trial and iteration, we arrived at a workflow that explains findings in context, advises you with reasoning, and lets you make the final call — not a raw code dump that assumes you know what a race condition is.

We also had to build cross-platform workarounds. Many agentic coding tools assume Linux-style sandboxing that quietly fails on Windows and macOS. This skill detects your platform, handles sandbox limitations explicitly, and works out of the box on Windows (Git Bash), macOS, Linux, and WSL.

**Install is straightforward:**

```
git clone https://github.com/razaumair2203-ux/codex-adversarial-review-lite.git
cd codex-adversarial-review-lite
bash scripts/install.sh
```

Then from Claude Code:

```
/codex-adversarial-review-lite audit
```

That is it. Build with Claude. Before you trust the change, audit it.

**Repo:** https://github.com/razaumair2203-ux/codex-adversarial-review-lite

If you are building with Claude Code or working with agentic coding workflows, I would genuinely love your feedback — what works, what is missing, what would make this more useful for your workflow. Open an issue or reach out.

Suggested image attachment:

docs/assets/audit-report-preview.jpg

#AIHallucination #VibeCoding #ClaudeCode #Codex #AgenticAI #CodeReview #AISafety #AICodeReview #CrossPlatform #LLM #BuildWithAI #ProductDevelopment
