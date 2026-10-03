#!/usr/bin/env bash
# Runs scripts/sync.sh against a local fixture upstream with tags.
set -euo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
failures=0

assert() { # description command...
  local what=$1
  shift
  if ! "$@"; then
    failures=$((failures + 1))
    echo "FAILED: $what"
  fi
}

git_q() { git -c user.name=t -c user.email=t@t -c commit.gpgsign=false -c tag.gpgsign=false "$@" >/dev/null; }

up="$tmp/upstream"
mkdir -p "$up/plugins/pstack/skills/a" "$up/plugins/pstack/skills/b"
printf -- '---\nname: a\ndescription: a\n---\n' > "$up/plugins/pstack/skills/a/SKILL.md"
printf -- '---\nname: b\ndescription: b\n---\n' > "$up/plugins/pstack/skills/b/SKILL.md"
printf '0.0.1\n' > "$up/VERSION"
printf 'upstream license\n' > "$up/LICENSE"
git_q -C "$up" init -b main
git_q -C "$up" add -A
git_q -C "$up" commit -m one
git_q -C "$up" tag v0.0.1

work="$tmp/work"
mkdir -p "$work/.omp-plugin"
cp -R "$repo/scripts" "$work/scripts"
cp "$repo/.omp-plugin/marketplace.json" "$work/.omp-plugin/marketplace.json"
git_q -C "$work" init -b main
export PSTACK_CLAUDE_REPO="$up"

version() { jq -r '.plugins[0].version' "$work/.omp-plugin/marketplace.json"; }

out=$(cd "$work" && bash scripts/sync.sh)
assert "first sync copies skills" test -f "$work/plugin/skills/a/SKILL.md" -a -f "$work/plugin/skills/b/SKILL.md"
assert "lock records tag" test "$(jq -r .tag "$work/upstream.lock.json")" = v0.0.1
assert "lock records version" test "$(jq -r .version "$work/upstream.lock.json")" = 0.0.1
assert "catalog version bumped to 0.0.1-omp.1" test "$(version)" = 0.0.1-omp.1
assert "upstream license copied" test -f "$work/upstream-licenses/LICENSE"
assert "reports added a" grep -qx 'added: a' <<<"$out"
assert "reports added b" grep -qx 'added: b' <<<"$out"

git_q -C "$work" add -A
git_q -C "$work" commit -m synced
(cd "$work" && bash scripts/sync.sh >/dev/null)
assert "rerun on same tag changes nothing" test -z "$(git -C "$work" status --porcelain)"

rm -rf "$up/plugins/pstack/skills/b"
mkdir -p "$up/plugins/pstack/skills/c"
printf -- '---\nname: c\ndescription: c\n---\n' > "$up/plugins/pstack/skills/c/SKILL.md"
printf '0.0.2\n' > "$up/VERSION"
git_q -C "$up" add -A
git_q -C "$up" commit -m two
git_q -C "$up" tag v0.0.2

out=$(cd "$work" && bash scripts/sync.sh)
assert "removed upstream skill deleted" test ! -e "$work/plugin/skills/b"
assert "new upstream skill copied" test -f "$work/plugin/skills/c/SKILL.md"
assert "latest tag picked" test "$(jq -r .tag "$work/upstream.lock.json")" = v0.0.2
assert "catalog version bumped to 0.0.2-omp.1" test "$(version)" = 0.0.2-omp.1
assert "reports removed b" grep -qx 'removed: b' <<<"$out"
assert "reports added c" grep -qx 'added: c' <<<"$out"

jq '.plugins[0].version = "0.0.2-omp.3"' "$work/.omp-plugin/marketplace.json" > "$tmp/cat.json"
mv "$tmp/cat.json" "$work/.omp-plugin/marketplace.json"
(cd "$work" && bash scripts/sync.sh v0.0.2 >/dev/null)
assert "local version kept on same upstream version" test "$(version)" = 0.0.2-omp.3

if [ "$failures" -ne 0 ]; then
  echo "$failures assertion(s) failed"
  exit 1
fi
echo "all sync assertions passed"
