#!/usr/bin/env bash
# Fixture-based tests for scripts/check.sh.
set -euo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
check="$repo/scripts/check.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
failures=0
cases=0

skill() { # root name frontmatter-body text
  mkdir -p "$1/plugin/skills/$2"
  printf -- '---\n%b---\n\n%b\n' "$3" "$4" > "$1/plugin/skills/$2/SKILL.md"
}

valid_root() {
  local root=$1
  mkdir -p "$root/.omp-plugin" "$root/plugin/agents"
  printf '{"name":"pstack-omp","owner":{"name":"t"},"plugins":[{"name":"pstack","source":"./plugin","version":"0.0.1-omp.1"}]}\n' \
    > "$root/.omp-plugin/marketplace.json"
  printf -- '---\nname: poteto-agent\ndescription: d\n---\nbody\n' > "$root/plugin/agents/poteto-agent.md"
  skill "$root" a 'name: a\ndescription: does a\n' \
    'Spawn `subagent_type: "pstack:poteto-agent"`, `pstack:poteto-agent-high`, `pstack:effort-max`, then `pstack:a`.'
}

expect() { # case-name want-exit want-substring
  local name=$1 want=$2 needle=$3 out rc=0
  cases=$((cases + 1))
  out=$(bash "$check" "$tmp/$name" 2>&1) || rc=$?
  if [ "$rc" -ne "$want" ] || [[ "$out" != *"$needle"* ]]; then
    failures=$((failures + 1))
    printf 'FAILED %s: exit %s (want %s), output:\n%s\n' "$name" "$rc" "$want" "$out"
  fi
}

valid_root "$tmp/valid"
expect valid 0 'OK: 1 skills, 1 agents'

valid_root "$tmp/missing-description"
skill "$tmp/missing-description" b 'name: b\n' 'text'
expect missing-description 1 'FAIL: plugin/skills/b/SKILL.md missing description'

valid_root "$tmp/unknown-agent"
skill "$tmp/unknown-agent" c 'name: c\ndescription: c\n' 'use `subagent_type: "pstack:ghost"`'
expect unknown-agent 1 'FAIL: unknown agent pstack:ghost'

valid_root "$tmp/dangling-skill"
skill "$tmp/dangling-skill" d 'name: d\ndescription: d\n' 'see pstack:nope'
expect dangling-skill 1 'FAIL: unknown skill pstack:nope'

valid_root "$tmp/bad-json"
printf '{' > "$tmp/bad-json/.omp-plugin/marketplace.json"
expect bad-json 1 'FAIL: .omp-plugin/marketplace.json invalid JSON'

if [ "$failures" -ne 0 ]; then
  echo "$failures of $cases cases failed"
  exit 1
fi
echo "all $cases cases passed"
