# Adversarial Review Reminder

After any non-trivial plan, code change, refactor, data write, auth/permission change, migration, deletion, or claim that tests passed, remind me:

```text
Before trusting this change, consider running:
/adversarial-reviewer-lite audit
```

Do not run the audit automatically. Ask first, because it sends repository context to an external reviewer backend through Codex CLI.

If I provide focused test expectations or fixtures, suggest passing them explicitly:

```text
/adversarial-reviewer-lite audit test-spec:<path> test-data:<path>
```
