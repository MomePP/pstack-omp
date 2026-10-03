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
git clone -q --depth 1 --branch "$tag" "$src" "$tmp/up" 2>/dev/null
commit=$(git -C "$tmp/up" rev-parse HEAD)
version=$(tr -d '[:space:]' < "$tmp/up/VERSION")

mkdir -p plugin/skills upstream-licenses
before=$(ls plugin/skills)
rsync -a --delete "$tmp/up/plugins/pstack/skills/" plugin/skills/
after=$(ls plugin/skills)
for f in LICENSE LICENSE-cursor-team-kit NOTICE.md NOTICE-skills.md; do
  [ -f "$tmp/up/$f" ] && cp "$tmp/up/$f" "upstream-licenses/$f"
done

previous=""
[ -f upstream.lock.json ] && previous=$(jq -r '.version' upstream.lock.json)
jq -n --arg repo "$repo" --arg tag "$tag" --arg commit "$commit" --arg version "$version" \
  '{repo: $repo, tag: $tag, commit: $commit, version: $version}' > upstream.lock.json

if [ "$previous" != "$version" ]; then
  jq --arg v "$version-omp.1" '.plugins[0].version = $v' .omp-plugin/marketplace.json > "$tmp/catalog.json"
  mv "$tmp/catalog.json" .omp-plugin/marketplace.json
fi

echo "synced $tag (${commit:0:7})"
comm -13 <(printf '%s\n' "$before") <(printf '%s\n' "$after") | sed '/^$/d; s/^/added: /'
comm -23 <(printf '%s\n' "$before") <(printf '%s\n' "$after") | sed '/^$/d; s/^/removed: /'
