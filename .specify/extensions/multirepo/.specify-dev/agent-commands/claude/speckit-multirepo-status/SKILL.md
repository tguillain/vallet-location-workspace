---
name: speckit-multirepo-status
description: Report branch, uncommitted work, commits ahead of trunk and push state for every repo the feature touched.
compatibility: Requires spec-kit project structure with .specify/ directory
metadata:
  author: Xefi
  source: multirepo:commands/speckit.multirepo.status.md
---

## Why this runs

A feature spanning two repositories produces two independent commits with no
transaction around them. Nothing can make that atomic, so the least the tooling
owes you is an accurate picture of where every repo ended up.

## What to do

1. Run the worker from the workspace root:

   ```bash
   .specify/extensions/multirepo/scripts/bash/status-repos.sh --plan specs/<feature>/plan.md
   ```

2. Show the table to the developer as-is. Do not summarise it away.

## How to read it

- **A repo not on the feature branch** — work may have landed on its trunk.
  This is the one the script exits non-zero for. Say so plainly.
- **Uncommitted files** — the feature is not finished, whatever the task list says.
- **Unpushed commits** — nobody else can see the work yet, so no merge request exists.

## What counts as done

Never describe the feature as complete while any affected repo has uncommitted
work, sits on the wrong branch, or has unpushed commits.

When every repo is clean and pushed, the remaining work is one merge request per
repo, cross-linked by the feature number. That is a process rule — no script
enforces it.