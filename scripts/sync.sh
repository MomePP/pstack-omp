#!/usr/bin/env bash
# Copies pstack-claude's skills at a release tag into plugin/skills/ verbatim, and prints a `port:` line for
# each upstream file that plugin/agents or plugin/rules port by hand and that differs from port.lock.json.
# Usage: scripts/sync.sh [TAG]         sync (default: latest v* tag)
#        scripts/sync.sh --ack TAG     record the watched files at TAG as ported, touching nothing else
set -euo pipefail

repo=${PSTACK_CLAUDE_REPO:-https://github.com/michael-denyer/pstack-claude}
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"

ack=false
if [ "${1:-}" = --ack ]; then
  ack=true
  shift
  [ -n "${1:-}" ] || { echo "sync: --ack needs the TAG you ported" >&2; exit 2; }
fi

verbatim_agents=(comment-sicko)
watched_paths=(plugins/pstack/agents plugins/pstack/omp plugins/pstack/hooks/session-start-context.md
  plugins/pstack/skills/poteto-mode/references/omp-tools.md)

src=$repo
[ -d "$repo" ] && src="file://$repo"

tag=${1:-$(git ls-remote --tags --refs --sort=-v:refname "$src" 'v*' | sed -n '1s#.*refs/tags/##p')}
[ -n "$tag" ] || { echo "sync: no v* tag found in $repo" >&2; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
git -c advice.detachedHead=false clone -q --depth 1 --branch "$tag" "$src" "$tmp/up" \
  || { echo "sync: cannot clone $repo at $tag" >&2; exit 1; }

verbatim_json=$(for a in "${verbatim_agents[@]}"; do echo "plugins/pstack/agents/$a.md"; done | jq -R . | jq -s .)
files_json=$(git -C "$tmp/up" ls-tree -r HEAD -- "${watched_paths[@]}" \
  | jq -R -n --argjson skip "$verbatim_json" '
      [inputs | capture("^[0-9]+ blob (?<sha>[0-9a-f]+)\t(?<path>.*)$")
       | select(.path as $p | $skip | index($p) | not)
       | {key: .path, value: .sha}] | from_entries' \
  | jq -S .)

if $ack; then
  jq -n --arg tag "$tag" --argjson files "$files_json" '{tag: $tag, files: $files}' > port.lock.json
  echo "acked $tag: $(jq '.files | length' port.lock.json) files"
  exit 0
fi

commit=$(git -C "$tmp/up" rev-parse HEAD)
version=$(tr -d '[:space:]' < "$tmp/up/VERSION")

# The catalog version moves whenever the synced content can change, so `omp plugin upgrade` sees it:
# a new upstream VERSION resets the suffix to omp.1; a new upstream commit under the same VERSION increments it.
current=$(jq -er '.plugins[0].version' .omp-plugin/marketplace.json)
locked_commit=$(jq -r '.commit // empty' upstream.lock.json 2>/dev/null || true)
suffix=0
[[ "$current" == *-omp.* ]] && suffix=${current##*-omp.}
if [ "${current%-omp.*}" != "$version" ]; then
  next="$version-omp.1"
elif [ -n "$locked_commit" ] && [ "$locked_commit" != "$commit" ]; then
  next="$version-omp.$((suffix + 1))"
else
  next=$current
fi

mkdir -p plugin/skills plugin/agents upstream-licenses
before=$(ls plugin/skills)
rsync -a --delete "$tmp/up/plugins/pstack/skills/" plugin/skills/
after=$(ls plugin/skills)
for f in LICENSE LICENSE-cursor-team-kit NOTICE.md NOTICE-skills.md; do
  [ -f "$tmp/up/$f" ] && cp "$tmp/up/$f" "upstream-licenses/$f"
done
removed_agents=()
for a in "${verbatim_agents[@]}"; do
  if [ -f "$tmp/up/plugins/pstack/agents/$a.md" ]; then
    cp "$tmp/up/plugins/pstack/agents/$a.md" "plugin/agents/$a.md"
  else
    removed_agents+=("plugins/pstack/agents/$a.md")
  fi
done

jq --arg v "$next" '.plugins[0].version = $v' .omp-plugin/marketplace.json > "$tmp/catalog.json"
mv "$tmp/catalog.json" .omp-plugin/marketplace.json
jq -n --arg repo "$repo" --arg tag "$tag" --arg commit "$commit" --arg version "$version" \
  '{repo: $repo, tag: $tag, commit: $commit, version: $version}' > upstream.lock.json

echo "synced $tag (${commit:0:7})"
comm -13 <(printf '%s\n' "$before") <(printf '%s\n' "$after") | sed '/^$/d; s/^/added: /'
comm -23 <(printf '%s\n' "$before") <(printf '%s\n' "$after") | sed '/^$/d; s/^/removed: /'

recorded=$(jq -c '.files // {}' port.lock.json 2>/dev/null || echo '{}')
jq -nr --argjson new "$files_json" --argjson old "$recorded" '
  ($new | to_entries[] | select($old[.key] != .value) | "port: " + .key),
  ($old | keys[] | select($new[.] == null) | "port: " + . + " (removed upstream)")' | sort
for p in ${removed_agents[@]+"${removed_agents[@]}"}; do
  echo "port: $p (removed upstream)"
done
