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
    'Spawn `subagent_type: "pstack:poteto-agent"`, then `pstack:a`.'
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

valid_root "$tmp/no-version"
printf '{"name":"pstack-omp","plugins":[{"name":"pstack"}]}\n' > "$tmp/no-version/.omp-plugin/marketplace.json"
expect no-version 1 'FAIL: .omp-plugin/marketplace.json missing plugins[0].version'

valid_root "$tmp/empty-skills"
rm -rf "$tmp/empty-skills/plugin/skills/a"
expect empty-skills 1 'FAIL: no skills under plugin/skills'

valid_root "$tmp/rule-dangling"
mkdir -p "$tmp/rule-dangling/plugin/rules"
printf -- '---\nalwaysApply: true\n---\nRead `skill://a`, `skill://a/references/x.md`, `skill://principle-<name>`, then `skill://gone`.\n' \
  > "$tmp/rule-dangling/plugin/rules/r.md"
expect rule-dangling 1 'FAIL: unknown skill skill://gone in plugin/rules/r.md'

valid_root "$tmp/autoload-dangling"
printf -- '---\nname: poteto-agent\ndescription: d\nautoloadSkills: [a, gone]\n---\nbody\n' > "$tmp/autoload-dangling/plugin/agents/poteto-agent.md"
expect autoload-dangling 1 'FAIL: unknown autoload skill gone in plugin/agents/poteto-agent.md'

omp_pointer='On OMP, read [`references/omp-tools.md`](references/omp-tools.md) instead.'

valid_root "$tmp/omp-pointer"
skill "$tmp/omp-pointer" e 'name: e\ndescription: e\n' "$omp_pointer"
expect omp-pointer 1 'FAIL: skills point OMP at omp-tools.md; plugin/rules/pstack-routing.md does not override it'

valid_root "$tmp/omp-pointer-overridden"
skill "$tmp/omp-pointer-overridden" e 'name: e\ndescription: e\n' "$omp_pointer"
mkdir -p "$tmp/omp-pointer-overridden/plugin/rules"
printf -- '---\nalwaysApply: true\n---\nIgnore `omp-tools.md`.\n' > "$tmp/omp-pointer-overridden/plugin/rules/pstack-routing.md"
expect omp-pointer-overridden 0 'OK: 2 skills, 1 agents'

valid_root "$tmp/omp-pointer-anchor"
skill "$tmp/omp-pointer-anchor" e 'name: e\ndescription: e\n' \
  'On OMP, follow [OMP setup](../poteto-mode/references/omp-tools.md#model-names) instead.'
expect omp-pointer-anchor 1 'FAIL: skills point OMP at omp-tools.md;'

valid_root "$tmp/omp-pointer-substring"
skill "$tmp/omp-pointer-substring" e 'name: e\ndescription: e\n' 'On OMP, read [map](references/tools.md).'
mkdir -p "$tmp/omp-pointer-substring/plugin/rules"
printf -- '---\nalwaysApply: true\n---\nIgnore `omp-tools.md`.\n' > "$tmp/omp-pointer-substring/plugin/rules/pstack-routing.md"
expect omp-pointer-substring 1 'FAIL: skills point OMP at tools.md;'

valid_root "$tmp/effort-form"
skill "$tmp/effort-form" f 'name: f\ndescription: f\n' 'use `subagent_type: "pstack:poteto-agent-high"`'
expect effort-form 1 'FAIL: unknown agent pstack:poteto-agent-high'

valid_root "$tmp/bad-port-lock"
printf '{' > "$tmp/bad-port-lock/port.lock.json"
expect bad-port-lock 1 'FAIL: port.lock.json invalid JSON'

valid_root "$tmp/good-port-lock"
printf '{"tag":"v1","files":{}}\n' > "$tmp/good-port-lock/port.lock.json"
expect good-port-lock 0 'OK: 1 skills, 1 agents'

panels() { # root rule-panel upstream-panel (upstream-panel empty: no codex-tools.md)
  mkdir -p "$1/plugin/rules"
  printf -- '---\nalwaysApply: true\n---\n- Diverse-model panels (%s) stay diverse.\n' "$2" > "$1/plugin/rules/pstack-omp-tools.md"
  [ -z "$3" ] && return 0
  mkdir -p "$1/plugin/skills/poteto-mode/references"
  printf -- '- Diverse-model panels (%s): the signal comes from diversity.\n' "$3" > "$1/plugin/skills/poteto-mode/references/codex-tools.md"
}

valid_root "$tmp/panel-match"
panels "$tmp/panel-match" '`arena`, `interrogate`' '`arena`, `interrogate`'
expect panel-match 0 'OK: 1 skills, 1 agents'

valid_root "$tmp/panel-mismatch"
panels "$tmp/panel-mismatch" '`arena`, `architect`, `interrogate`' '`arena`, `interrogate`'
expect panel-mismatch 1 'FAIL: panel list in plugin/rules/pstack-omp-tools.md (arena, architect, interrogate) differs from upstream (arena, interrogate)'

valid_root "$tmp/panel-upstream-missing"
panels "$tmp/panel-upstream-missing" '`arena`' ''
expect panel-upstream-missing 1 'FAIL: cannot find upstream panel list in codex-tools.md'

valid_root "$tmp/panel-upstream-no-line"
panels "$tmp/panel-upstream-no-line" '`arena`' '`arena`'
printf 'nothing here\n' > "$tmp/panel-upstream-no-line/plugin/skills/poteto-mode/references/codex-tools.md"
expect panel-upstream-no-line 1 'FAIL: cannot find upstream panel list in codex-tools.md'

pinned() { # root file-name body
  printf -- '---\nname: %s\ndescription: d\nmodel: x\n---\n%s\n' "${2%.md}" "$3" > "$1/plugin/agents/$2"
}

valid_root "$tmp/pinned-ok"
pinned "$tmp/pinned-ok" poteto-opus.md body
pinned "$tmp/pinned-ok" task-opus.md work
pinned "$tmp/pinned-ok" task-sonnet.md work
expect pinned-ok 0 'OK: 1 skills, 4 agents'

valid_root "$tmp/pinned-poteto-drift"
pinned "$tmp/pinned-poteto-drift" poteto-opus.md 'edited by hand'
expect pinned-poteto-drift 1 'FAIL: plugin/agents/poteto-opus.md body differs from plugin/agents/poteto-agent.md'

valid_root "$tmp/pinned-task-drift"
pinned "$tmp/pinned-task-drift" task-opus.md work
pinned "$tmp/pinned-task-drift" task-sonnet.md 'edited by hand'
expect pinned-task-drift 1 'FAIL: plugin/agents/task-sonnet.md body differs from plugin/agents/task-opus.md'

if [ "$failures" -ne 0 ]; then
  echo "$failures of $cases cases failed"
  exit 1
fi
echo "all $cases cases passed"
