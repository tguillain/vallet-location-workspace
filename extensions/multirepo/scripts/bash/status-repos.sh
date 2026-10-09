#!/usr/bin/env bash
#
# after_implement hook: report what every affected child repo actually ended up
# with — branch, uncommitted files, commits ahead of trunk, push state.
#
# A feature spanning two repos produces two commits in two repositories with no
# transaction around them, so nothing can make it atomic. This makes the result
# visible, which is the most the tooling can do. Exits non-zero when a repo is
# on the wrong branch, because that means work may have landed on its trunk.
#
#   status-repos.sh [--plan specs/014-quota/plan.md] [--branch NAME] [--json]

set -uo pipefail

HERE="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/multirepo-common.sh"

PLAN=""; BRANCH=""; JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --plan)   PLAN="${2:-}"; shift 2 ;;
    --branch) BRANCH="${2:-}"; shift 2 ;;
    --json)   JSON=1; shift ;;
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

rows=()
wrong_branch=0

for dir in "${REPOS[@]}"; do
  path="$ROOT/$dir"
  trunk="$(repo_field "$ROOT" "$dir" 3)" || trunk="?"
  if [ ! -d "$path/.git" ]; then
    rows+=("$dir|missing|?|?|?|not cloned")
    wrong_branch=$((wrong_branch + 1))
    continue
  fi

  branch="$(git -C "$path" rev-parse --abbrev-ref HEAD 2>/dev/null)"
  dirty="$(git -C "$path" status --porcelain 2>/dev/null | grep -c .)"
  ahead="$(git -C "$path" rev-list --count "$trunk..HEAD" 2>/dev/null || echo '?')"

  # Compare against the remote copy of THIS branch, not against @{upstream}: a
  # branch cut from origin/<trunk> inherits the trunk as upstream, so an
  # upstream comparison reports "pushed" for a branch the remote never saw.
  if git -C "$path" show-ref --verify --quiet "refs/remotes/origin/$branch"; then
    unpushed="$(git -C "$path" rev-list --count "origin/$branch..HEAD" 2>/dev/null || echo '?')"
    [ "$unpushed" = "0" ] && push="pushed" || push="$unpushed unpushed"
  else
    push="never pushed"
  fi

  [ "$branch" = "$BRANCH" ] || wrong_branch=$((wrong_branch + 1))
  rows+=("$dir|$branch|$dirty|$ahead|$push|")
done

if [ "$JSON" -eq 1 ]; then
  printf '{"branch":"%s","repos":[' "$BRANCH"
  for index in "${!rows[@]}"; do
    IFS='|' read -r dir branch dirty ahead push _ <<< "${rows[$index]}"
    [ "$index" -gt 0 ] && printf ','
    printf '{"dir":"%s","branch":"%s","uncommitted":"%s","ahead":"%s","push":"%s"}' \
      "$dir" "$branch" "$dirty" "$ahead" "$push"
  done
  printf '],"off_branch":%d}\n' "$wrong_branch"
else
  printf '\nFeature branch: %s\n\n' "$BRANCH"
  printf '%-22s %-24s %12s %8s  %s\n' "REPO" "BRANCH" "UNCOMMITTED" "AHEAD" "PUSH"
  for row in "${rows[@]}"; do
    IFS='|' read -r dir branch dirty ahead push _ <<< "$row"
    marker=""
    [ "$dirty" != "0" ] && marker="  <- uncommitted work"
    [ "$branch" = "$BRANCH" ] || marker="  <- NOT on the feature branch"
    printf '%-22s %-24s %12s %8s  %s%s\n' "$dir" "$branch" "$dirty" "$ahead" "$push" "$marker"
  done
  printf '\n'
fi

if [ "$wrong_branch" -gt 0 ]; then
  echo "$wrong_branch repo(s) are not on $BRANCH — work may have landed on a trunk" >&2
  exit 1
fi
