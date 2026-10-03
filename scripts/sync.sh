#!/usr/bin/env bash
# Copies pstack-claude's skills at a release tag into plugin/skills/ verbatim.
# Usage: scripts/sync.sh [TAG]   (default: latest v* tag)
set -euo pipefail

repo=${PSTACK_CLAUDE_REPO:-https://github.com/michael-denyer/pstack-claude}
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"

src=$repo
[ -d "$repo" ] && src="file://$repo"

tag=${1:-$(git ls-remote --tags --refs --sort=-v:refname "$src" 'v*' | head -n 1 | sed 's#.*refs/tags/##')}
[ -n "$tag" ] || { echo "sync: no v* tag found in $repo" >&2; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
git -c advice.detachedHead=false clone -q --depth 1 --branch "$tag" "$src" "$tmp/up" \
  || { echo "sync: cannot clone $repo at $tag" >&2; exit 1; }
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

mkdir -p plugin/skills upstream-licenses
before=$(ls plugin/skills)
rsync -a --delete "$tmp/up/plugins/pstack/skills/" plugin/skills/
after=$(ls plugin/skills)
for f in LICENSE LICENSE-cursor-team-kit NOTICE.md NOTICE-skills.md; do
  [ -f "$tmp/up/$f" ] && cp "$tmp/up/$f" "upstream-licenses/$f"
done

jq --arg v "$next" '.plugins[0].version = $v' .omp-plugin/marketplace.json > "$tmp/catalog.json"
mv "$tmp/catalog.json" .omp-plugin/marketplace.json
jq -n --arg repo "$repo" --arg tag "$tag" --arg commit "$commit" --arg version "$version" \
  '{repo: $repo, tag: $tag, commit: $commit, version: $version}' > upstream.lock.json

echo "synced $tag (${commit:0:7})"
comm -13 <(printf '%s\n' "$before") <(printf '%s\n' "$after") | sed '/^$/d; s/^/added: /'
comm -23 <(printf '%s\n' "$before") <(printf '%s\n' "$after") | sed '/^$/d; s/^/removed: /'
