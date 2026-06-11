# Windows Sandbox Notes

Adversarial Reviewer Lite v1 is Windows-first because many agentic coding tutorials assume Linux-style sandboxing, while many new users are working from Windows machines.

## The Problem

Codex CLI sandbox modes may rely on `bwrap`/bubblewrap. On Linux, `bwrap` can create a restricted filesystem/process sandbox. On Windows, `bwrap` is normally unavailable, so sandbox preflight checks fail before the reviewer can run.

That failure can look like:

```text
bwrap: command not found
sandbox setup failed
permission denied
```

## Adversarial Reviewer Lite's Default

On Windows, Adversarial Reviewer Lite v1 defaults to:

```text
sandbox:danger-full-access
```

This avoids the common `bwrap` failure, but it means the reviewer backend can run with broad filesystem access. This is a pragmatic compatibility choice for the first release, not a security boundary.

## Why This Can Still Be Useful

The workflow adds guardrails around that power:

- The reviewer prompt says it is an auditor, not a contributor.
- The reviewer is told not to create, edit, delete, commit, or apply fixes.
- The builder captures Git status before and after reviewer dispatch.
- Already-dirty tracked files are content-hashed before and after dispatch.
- Already-dirty tracked files are also passed to the runner as a do-not-touch warning list.
- If project files mutate during review, the workflow hard-stops.

These are detection and process controls, not a sandbox.

**Important caveat**: The content-hashing control relies on correct temp file paths. On Windows with Git Bash, `/tmp` maps to the Windows temp directory, but Claude Code's Write and Read tools may not resolve `/tmp` correctly. If hash files are written via Git Bash but read via a native-path tool (or vice versa), the hash baseline can be empty — causing the mutation comparison to silently produce a false-negative (no diff because both pre and post files are empty). The skill's "Claude Code Runtime Notes" section addresses this by requiring native-path resolution via `pwd -W` and non-empty verification after every hash capture. Always check that `.sha` files are non-empty before trusting the mutation check.

## Safer Alternatives

Try these when your environment supports them:

```text
sandbox:inherit
sandbox:read-only
sandbox:workspace-write
```

On many Windows Codex CLI setups, `read-only` and `workspace-write` still depend on `bwrap` and fail. `inherit` may work if your Codex config has a Windows-native safe mode.

## Recommended Practice

For sensitive repos:

- commit or stash work before running review;
- avoid ignored secret files inside the repo;
- use audit mode first;
- provide focused test specs/test data so the reviewer can check verification gaps without widening scope;
- prefer `approvals:never` or `approvals:user` if you want stricter control over reviewer commands;
- inspect the HTML report before accepting fixes;
- revoke or rotate credentials if a secret was ever pasted into a prompt.
