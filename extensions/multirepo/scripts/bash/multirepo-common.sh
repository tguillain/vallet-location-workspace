#!/usr/bin/env bash
#
# Shared helpers for the multirepo hooks — workspace root resolution, manifest
# lookups, and reading the Affected Repos block out of a plan.
#
# Sourced by branch-repos.sh and status-repos.sh, never executed on its own.

# Spec-kit resolves its project root by walking up for .specify/, ignoring git
# boundaries. Resolve the same way, so a hook invoked from inside a child repo
# still finds the workspace rather than the repo it happens to sit in.
workspace_root() {
  local dir="${1:-$PWD}"
  dir="$(CDPATH="" cd -- "$dir" 2>/dev/null && pwd)" || return 1
  while true; do
    [ -d "$dir/.specify" ] && { printf '%s\n' "$dir"; return 0; }
    [ "$dir" = "/" ] && return 1
    dir="$(dirname "$dir")"
  done
}

# The first column of the marked table the plan template writes. Names are
# validated against repos.yml by the callers — a typo here would otherwise
# leave a repo silently unbranched.
affected_repos() {
  awk '
    /speckit-multirepo:begin/ { inblock = 1; next }
    /speckit-multirepo:end/   { inblock = 0; next }
    !inblock                  { next }
    /^[[:space:]]*\|/ {
      row = $0
      sub(/^[[:space:]]*\|[[:space:]]*/, "", row)
      sub(/[[:space:]]*\|.*$/, "", row)
      gsub(/[[:space:]]*$/, "", row)
      gsub(/`/, "", row)
      if (row == "" || row ~ /^[-: ]+$/ || tolower(row) == "repo") next
      print row
    }
  ' "$1"
}

# Field index into `bin/repos list`: 1 dir, 2 url, 3 trunk, 4 stack, 5 setup.
repo_field() {
  local root="$1" dir="$2" index="$3"
  "$root/bin/repos" list 2>/dev/null |
    awk -F'\t' -v d="$dir" -v i="$index" '$1 == d { print $i; found = 1 } END { exit !found }'
}

# The feature branch name is the spec directory name: specs/014-quota/plan.md
# gives 014-quota, which is what spec-kit branched the workspace to.
feature_branch_from_plan() {
  basename "$(dirname "$1")"
}

resolve_plan() {
  local root="$1" given="$2"
  if [ -n "$given" ]; then
    [ -f "$given" ] && { printf '%s\n' "$given"; return 0; }
    echo "plan not found: $given" >&2
    return 1
  fi
  local newest
  newest="$(ls -1dt "$root"/specs/*/plan.md 2>/dev/null | head -1)"
  [ -n "$newest" ] && { printf '%s\n' "$newest"; return 0; }
  echo "no plan.md under $root/specs — run /speckit-plan first" >&2
  return 1
}
