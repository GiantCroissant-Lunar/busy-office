---
name: commit
description: Create a conventional commit in the busy-office repo with safety checks and pre-commit hook support.
disable-model-invocation: true
argument-hint: "[message]"
---

# Commit

Create a git commit in the busy-office repo using Conventional Commits.

## Pre-flight

Working directory: `C:\lunar-horse\yokan-projects\busy-office`
Current status: !`git status --short`
Recent commits: !`git log --oneline -5`

## Format

```
<type>(<scope>): <description>

[optional body]

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```

Types: `feat`, `fix`, `refactor`, `docs`, `test`, `build`, `chore`

Scopes: `bundles`, `hud`, `dock`, `bootstrap`, `build`, `ci`

## Rules

1. Stage specific files — never `git add -A` or `git add .`
2. Never commit secrets (`.env`, credentials)
3. Never skip hooks with `--no-verify`
4. If a hook fails: fix, re-stage, NEW commit (do NOT `--amend`)
5. If `$ARGUMENTS` is provided, use it as the commit message (still validate format)
6. If `$ARGUMENTS` is empty, analyze staged changes and draft a message
7. Use HEREDOC for the commit message to preserve formatting

## Workflow

1. `git status` — review changes
2. `git diff --stat` — understand scope
3. Stage relevant files by name
4. Commit with conventional message
5. `git log --oneline -1` — verify
