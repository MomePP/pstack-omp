#!/usr/bin/env bash
# Port gate: fails when the synced skills reference something OMP cannot resolve.
set -euo pipefail

root=${1:-$(cd "$(dirname "$0")/.." && pwd)}
cd "$root"

fails=0
fail() { echo "FAIL: $*"; fails=$((fails + 1)); }

for f in .omp-plugin/marketplace.json upstream.lock.json port.lock.json; do
  [ "$f" != .omp-plugin/marketplace.json ] && [ ! -e "$f" ] && continue
  jq empty "$f" 2>/dev/null || fail "$f invalid JSON"
done
if jq empty .omp-plugin/marketplace.json 2>/dev/null; then
  jq -e '.plugins[0].version | type == "string"' .omp-plugin/marketplace.json >/dev/null 2>&1 \
    || fail ".omp-plugin/marketplace.json missing plugins[0].version"
fi

frontmatter() { awk 'NR == 1 && $0 != "---" { exit } NR > 1 && $0 == "---" { exit } NR > 1 { print }' "$1"; }

skills=0
for f in plugin/skills/*/SKILL.md; do
  [ -e "$f" ] || continue
  skills=$((skills + 1))
  fm=$(frontmatter "$f")
  grep -q '^name:' <<<"$fm" || fail "$f missing name"
  grep -q '^description:' <<<"$fm" || fail "$f missing description"
done
[ "$skills" -gt 0 ] || fail "no skills under plugin/skills"

agents=()
for f in plugin/agents/*.md; do
  [ -e "$f" ] || continue
  name=$(frontmatter "$f" | sed -n 's/^name:[[:space:]]*//p' | head -n 1)
  [ -n "$name" ] && agents+=("$name")
  autoload=$(frontmatter "$f" | sed -n 's/^autoloadSkills:[[:space:]]*\[\(.*\)\]/\1/p' | tr ',' ' ')
  for x in $autoload; do
    [ -d "plugin/skills/$x" ] || fail "unknown autoload skill $x in $f"
  done
done

body() { awk 'NR == 1 && $0 == "---" { fm = 1; next } fm == 1 { if ($0 == "---") fm = 2; next } { print }' "$1"; }

same_body() { # reference file, file
  [ "$(body "$1")" = "$(body "$2")" ] || fail "$2 body differs from $1"
}
if [ -e plugin/agents/poteto-agent.md ]; then
  for f in plugin/agents/poteto-*.md; do
    [ "$f" = plugin/agents/poteto-agent.md ] && continue
    same_body plugin/agents/poteto-agent.md "$f"
  done
fi
task_ref=
for f in plugin/agents/task-*.md; do
  [ -e "$f" ] || continue
  if [ -z "$task_ref" ]; then task_ref=$f; else same_body "$task_ref" "$f"; fi
done

panel_list() { # backticked names inside "Diverse-model panels (...)"
  grep -m1 'Diverse-model panels (' "$1" 2>/dev/null \
    | sed -E 's/.*Diverse-model panels \(([^)]*)\).*/\1/' | grep -oE '`[^`]+`' | tr -d '`' | paste -sd, - | sed 's/,/, /g' || true
}
if [ -e plugin/rules/pstack-omp-tools.md ]; then
  upstream_panel=$(panel_list plugin/skills/poteto-mode/references/codex-tools.md)
  if [ -z "$upstream_panel" ]; then
    fail "cannot find upstream panel list in codex-tools.md"
  else
    rule_panel=$(panel_list plugin/rules/pstack-omp-tools.md)
    [ "$rule_panel" = "$upstream_panel" ] \
      || fail "panel list in plugin/rules/pstack-omp-tools.md ($rule_panel) differs from upstream ($upstream_panel)"
  fi
fi

for f in plugin/rules/*.md plugin/agents/*.md; do
  [ -e "$f" ] || continue
  for x in $(grep -oE 'skill://[a-z0-9-]+<?' "$f" | grep -v '<$' | sed 's#^skill://##' | sort -u); do
    [ -d "plugin/skills/$x" ] || fail "unknown skill skill://$x in $f"
  done
done

while IFS= read -r x; do
  [ -n "$x" ] || continue
  grep -qF "\`$x\`" plugin/rules/pstack-routing.md 2>/dev/null \
    || fail "skills point OMP at $x; plugin/rules/pstack-routing.md does not override it"
done < <(grep -rhoE 'On OMP[^(]*\]\([^)#]+' plugin/skills 2>/dev/null | sed 's#.*/##' | sort -u || true)

is_shipped_agent() {
  local x=$1 a
  for a in ${agents[@]+"${agents[@]}"}; do [ "$x" = "$a" ] && return 0; done
  return 1
}

subagent_refs=$(grep -rhoE 'subagent_type: ?"pstack:[a-z0-9-]+"' plugin/skills 2>/dev/null \
  | sed -E 's/.*"pstack:([a-z0-9-]+)"/\1/' | sort -u || true)
for x in $subagent_refs; do
  is_shipped_agent "$x" || fail "unknown agent pstack:$x"
done

refs=$(grep -rhoE 'pstack:[a-z0-9-]+' plugin/skills 2>/dev/null | sed 's/^pstack://' | sort -u || true)
for x in $refs; do
  grep -qxF "$x" <<<"$subagent_refs" && continue
  is_shipped_agent "$x" && continue
  [ -d "plugin/skills/$x" ] && continue
  fail "unknown skill pstack:$x"
done

if [ "$fails" -ne 0 ]; then
  echo "$fails problem(s)"
  exit 1
fi
echo "OK: $skills skills, ${#agents[@]} agents"
