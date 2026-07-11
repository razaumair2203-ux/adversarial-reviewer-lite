# Why Independent Review Helps

Codex Adversarial Review - Lite v1 uses a focused builder/reviewer split for agentic coding work.

- The **builder** is Claude Code.
- The **reviewer** is Codex CLI.
- The **user** keeps final authority, especially in audit mode.

The claim is intentionally modest: adversarial review can reduce blind spots and improve the quality of agentic work, but it does not prove correctness.

## Why Not Just Ask The Builder To Review Itself?

Self-review can help, but it often shares the same assumptions as the original answer. If the builder hallucinated an API, misunderstood the repo, or stretched the task scope, a same-model self-review may preserve the same mistake.

An independent reviewer can bring different priors, different training artifacts, different tool behavior, and a different failure profile. That diversity is useful, but not sufficient. The builder must still verify each finding.

## Why Not An Internal Subagent Only?

An internal subagent can still be useful, especially when it has separate context, a different prompt, or stricter instructions. But it often shares important failure surfaces with the builder:

- same model family or serving stack;
- same local assumptions from the conversation;
- same tool defaults and blind spots;
- same tendency to over-trust the current plan.

A third-party reviewer backend adds operational separation. It may use a different model, CLI, prompt harness, command behavior, and error surface. That separation is not magic, but it makes correlated failure less likely.

Codex Adversarial Review - Lite keeps the claim modest: independent review is a pressure test, not a proof. The builder remains responsible for validating reviewer observations and presenting the report before touching code.

## Why It Can Improve Agentic Coding Work

Agentic coding tools are fast, but speed creates predictable failure modes:

- the builder assumes a package, API, or CLI option exists;
- the builder implements a broader change than the user asked for;
- the builder writes happy-path tests but misses edge cases;
- the builder explains success before verification is complete;
- the builder accepts review feedback too obediently and over-refactors.

Adversarial review improves the workflow by adding a second, intentionally skeptical pass before code is touched again. The reviewer is asked to look for correctness, safety, scope, and verification risks. The builder is then forced to classify each finding as accepted, rejected, re-scoped, deferred, or needing empirical verification.

That extra friction is useful for beginners because it turns vague "AI reviewed it" confidence into a visible decision trail.

## Research Signals

Useful starting points, with the practical takeaway for this skill:

- Self-Refine shows that feedback-and-refinement can improve model outputs, even when one model plays generator, critic, and refiner. This supports review loops in principle, but it does not prove same-model review is always enough: https://arxiv.org/abs/2303.17651
- Reflexion explores feedback and memory for agents, reinforcing that agents benefit from structured reflection and learning from failures: https://arxiv.org/abs/2303.11366
- Huang et al. report that LLMs can struggle to self-correct reasoning without external feedback, and can even degrade correct answers. This supports using external signals instead of relying only on "review yourself": https://arxiv.org/abs/2310.01798
- Multi-agent debate shows that multiple model instances can improve factuality and reasoning in some settings, supporting the broader idea that independent perspectives can reduce hallucinations: https://arxiv.org/abs/2305.14325
- A 2024 critical survey reports that prompted self-correction is unreliable without reliable feedback, while external feedback and task-specific signals are more promising: https://aclanthology.org/2024.tacl-1.78/
- A 2025 LLM code-review evaluation found that review performance depends on context and task type. This supports passing problem descriptions, focused test specs, and expected behavior rather than asking for generic review: https://arxiv.org/abs/2505.20206
- A 2026 vision paper on agentic code review argues for specialized agents with human-controlled quality gates, which matches this skill's report-before-code and sign-off posture: https://arxiv.org/abs/2605.17548

Two frontier models can still share a training-distribution blind spot — neither reliably knowing an obscure regulatory deadline or evidentiary rule, for instance — no matter how independent their architectures are. Independent review narrows correlated failure; it does not eliminate blind spots the reviewer never had information about in the first place. This is why `rubric:<path>` exists: a named checklist converts "does this look fine to a smart generalist" into "does this satisfy these specific rules," which is checkable even when neither model would have raised the issue unprompted.

The practical takeaway is modest:

```text
External review can reduce blind spots, but reviewer findings are suggestions to verify, not orders to obey.
```

## What Codex Adversarial Review - Lite Optimizes For

Codex Adversarial Review - Lite is not trying to replace CI, tests, or human review. It is a local workflow for catching common agentic coding failure modes earlier:

- hallucinated APIs;
- overbroad changes;
- fragile happy-path fixes;
- missing rollback or data integrity checks;
- unverified claims in summaries;
- stale assumptions about libraries or CLIs;
- weak or missing tests for the user's actual expected behavior.

The HTML report is deliberately written for newer users. It explains what can go wrong, why it matters, what test expectations were considered, and what the builder believes after checking the review.

## What Public Tools Already Do

Public repos and tools commonly offer parts of this pattern:

- code review bots that comment on pull requests;
- LLM-as-judge evaluation harnesses;
- multi-agent debate or critique loops;
- local CLI wrappers around model review;
- prompt-only "review my code" workflows.

Examples in the broader space include AI pair-programming CLIs, PR review tools, and repository-level review agents. Many are powerful, but they usually optimize for teams, pull requests, or autonomous coding. Codex Adversarial Review - Lite's smaller angle is the local beginner workflow: Claude Code builder, Codex reviewer, platform-aware sandbox handling (Windows, macOS, Linux, WSL), focused test-spec review, dirty-file mutation detection, explicit finding verification, user sign-off in audit mode, and a simple HTML artifact that explains decisions before code changes.
