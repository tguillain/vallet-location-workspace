#!/usr/bin/env bash
#
# before_implement hook: create or switch to the feature branch in every child
# repo the plan names, cut from that repo's own trunk.
#
# Spec-kit's bundled git extension branches exactly one repository — the one
# holding .specify/, which in a workspace is the workspace itself. The code is
# in the children, so without this the implementation lands on whatever branch
# each child happened to be sitting on, usually its trunk.
#
# Refuses to continue on any failure. A half-branched workspace is worse than
# one that never started.
#
#   branch-repos.sh [--plan specs/014-quota/plan.md] [--branch NAME] [--dry-run] [--json]

set -uo pipefail

HERE="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/multirepo-common.sh"

PLAN=""; BRANCH=""; DRY_RUN=0; JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --plan)    PLAN="${2:-}"; shift 2 ;;
    --branch)  BRANCH="${2:-}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --json)    JSON=1; shift ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

ROOT="$(workspace_root)" || { echo "not inside a spec-kit workspace (no .specify/ above)" >&2; exit 1; }
PLAN="$(resolve_plan "$ROOT" "$PLAN")" || exit 1
[ -n "$BRANCH" ] || BRANCH="$(feature_branch_from_plan "$PLAN")"

mapfile -t REPOS < <(affected_repos "$PLAN")
if [ "${#REPOS[@]}" -eq 0 ]; then
  echo "plan names no affected repo — add the Affected Repos block to $PLAN" >&2
  exit 1
fi

results=()
failures=0

for dir in "${REPOS[@]}"; do
  trunk="$(repo_field "$ROOT" "$dir" 3)" || {
    echo "fail  $dir is not declared in repos.yml — fix the plan or ./bin/repos add it" >&2
    failures=$((failures + 1)); results+=("$dir|unknown|not-in-manifest"); continue
  }
  path="$ROOT/$dir"
  if [ ! -d "$path/.git" ]; then
    echo "fail  $dir is not cloned — run ./bootstrap --only $dir" >&2
    failures=$((failures + 1)); results+=("$dir|$trunk|not-cloned"); continue
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "dry   $dir would branch $BRANCH from $trunk"
    results+=("$dir|$trunk|dry-run"); continue
  fi

  git -C "$path" fetch --quiet origin 2>/dev/null

  if git -C "$path" show-ref --verify --quiet "refs/heads/$BRANCH"; then
    if git -C "$path" checkout --quiet "$BRANCH" 2>/dev/null; then
      echo "ok    $dir on $BRANCH (existing)"
      results+=("$dir|$trunk|switched")
    else
      echo "fail  $dir could not switch to $BRANCH — uncommitted changes?" >&2
      failures=$((failures + 1)); results+=("$dir|$trunk|checkout-failed")
    fi
    continue
  fi

  start="origin/$trunk"
  git -C "$path" show-ref --verify --quiet "refs/remotes/origin/$trunk" || start="$trunk"
  if git -C "$path" checkout --quiet -b "$BRANCH" "$start" 2>/dev/null; then
    echo "ok    $dir on $BRANCH (new, from $start)"
    results+=("$dir|$trunk|created")
  else
    echo "fail  $dir could not branch $BRANCH from $start" >&2
    failures=$((failures + 1)); results+=("$dir|$trunk|branch-failed")
  fi
done

if [ "$JSON" -eq 1 ]; then
  printf '{"branch":"%s","plan":"%s","repos":[' "$BRANCH" "$PLAN"
  for index in "${!results[@]}"; do
    IFS='|' read -r dir trunk state <<< "${results[$index]}"
    [ "$index" -gt 0 ] && printf ','
    printf '{"dir":"%s","trunk":"%s","state":"%s"}' "$dir" "$trunk" "$state"
  done
  printf '],"failures":%d}\n' "$failures"
fi

[ "$failures" -eq 0 ] || { echo "$failures repo(s) not branched — implementation must not start" >&2; exit 1; }
