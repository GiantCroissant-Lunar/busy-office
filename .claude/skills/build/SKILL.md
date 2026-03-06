---
name: build
description: Build, export, and run the busy-office Godot app and bundle PCKs. Use when the user says "build", "export", "pack", "run", or needs to build a specific bundle.
disable-model-invocation: true
argument-hint: "[app|bundles|bundle:<name>|run]"
allowed-tools: Bash, Read, Glob
---

# Build

Build and run the busy-office Godot project.

## Current state

Git branch: !`git branch --show-current`
Dirty files: !`git status --short`

## Commands

| Action | Command |
|--------|---------|
| Export app EXE | `task build:app` |
| Build ALL bundle PCKs | `task build:bundles` |
| Build one bundle | `task build:bundle:<name>` |
| Run exported app | `task run:complete-app` |
| Open in Godot editor | `task run:complete-app:editor` |
| Open content-authoring editor | `task run:content-authoring` |

## Routing

Parse `$ARGUMENTS` to decide what to build:

- **`app`** or empty — `task build:app`
- **`bundles`** — `task build:bundles`
- **`bundle:<name>`** — `task build:bundle:<name>` (e.g. `bundle:panel-welcome`)
- **`run`** — `task build:app && task run:complete-app`
- **`all`** — `task build:app && task build:bundles`

If `$ARGUMENTS` is empty, infer from recently changed files:
- Changes in `project/hosts/complete-app/` → build app
- Changes in `project/hosts/content-authoring/bundles/<name>/` → build that bundle
- Changes in `project/plugins/` or `project/contracts/` → build app

## Important

- `build:app` does NOT rebuild bundle PCKs. If GDScript in bundles changed, also run `task build:bundles`.
- After building, verify the app runs: `task run:complete-app`.
- Godot binary: `C:\lunar-horse\tools\Godot_v4.6.1-stable_mono_win64\`
