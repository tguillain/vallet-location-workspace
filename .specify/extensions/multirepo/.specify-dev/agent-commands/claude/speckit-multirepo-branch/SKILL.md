---
name: speckit-multirepo-branch
description: Create or switch to the feature branch in every child repo the plan names, cut from that repo's own trunk.
compatibility: Requires spec-kit project structure with .specify/ directory
metadata:
  author: Xefi
  source: multirepo:commands/speckit.multirepo.branch.md
---

## Why this runs

The code for this feature lives in the child repos, not in the workspace that
holds `.specify/`. Spec-kit's bundled `git` extension branches only the project
root, so without this step implementation writes into repos still sitting on
their trunks.

## What to do

1. Locate the current feature's `plan.md` under `specs/`.

2. Confirm it carries an **Affected Repos** block. If it does not, stop and say
   so — the plan has to name which repos the feature touches before anything can
   be branched. Do not guess the list.

3. Run the worker from the workspace root:

   ```bash
   .specify/extensions/multirepo/scripts/bash/branch-repos.sh --plan specs/<feature>/plan.md
   ```

4. Read its output. It exits non-zero when a repo is missing from `repos.yml`,
   is not cloned, or could not be checked out.

## On failure

**Stop. Do not start implementing.** A workspace where only some repos got
branched will land part of the feature on a trunk, and that is harder to unpick
than starting over. Report which repo failed and why.

Common causes, in order of frequency:

- The repo is named in `plan.md` but not declared in `repos.yml` — either the
  plan has a typo, or the repo needs `./bin/repos add <clone-url>`.
- The repo is declared but not cloned — run `./bootstrap --only <dir>`.
- The checkout failed because that repo has uncommitted changes — the developer
  has to deal with those first; do not stash or discard them.