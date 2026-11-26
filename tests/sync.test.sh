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
mkdir -p "$up/plugins/pstack/skills/a" "$up/plugins/pstack/skills/b" "$up/plugins/pstack/agents"
printf -- '---\nname: a\ndescription: a\n---\n' > "$up/plugins/pstack/skills/a/SKILL.md"
printf -- '---\nname: b\ndescription: b\n---\n' > "$up/plugins/pstack/skills/b/SKILL.md"
printf 'agent\n' > "$up/plugins/pstack/agents/x.md"
printf 'verbatim\n' > "$up/plugins/pstack/agents/comment-sicko.md"
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
assert "verbatim agent copied into plugin/agents" cmp -s "$up/plugins/pstack/agents/comment-sicko.md" "$work/plugin/agents/comment-sicko.md"
assert "missing port.lock reports every watched file" grep -qx 'port: plugins/pstack/agents/x.md' <<<"$out"
assert "verbatim agent is never reported" test -z "$(grep 'comment-sicko' <<<"$out" || true)"
assert "sync never writes port.lock.json" test ! -e "$work/port.lock.json"

ack=$(cd "$work" && bash scripts/sync.sh --ack v0.0.1)
assert "ack prints the tag and file count" test "$ack" = "acked v0.0.1: 1 files"
assert "ack records the tag" test "$(jq -r .tag "$work/port.lock.json")" = v0.0.1
assert "ack records watched files without the verbatim agent" test "$(jq -c '.files | keys' "$work/port.lock.json")" = '["plugins/pstack/agents/x.md"]'

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
assert "skill-only upstream change reports nothing to port" test -z "$(grep '^port: ' <<<"$out" || true)"

jq '.plugins[0].version = "0.0.2-omp.3"' "$work/.omp-plugin/marketplace.json" > "$tmp/cat.json"
mv "$tmp/cat.json" "$work/.omp-plugin/marketplace.json"
(cd "$work" && bash scripts/sync.sh v0.0.2 >/dev/null)
assert "local version kept on same upstream version" test "$(version)" = 0.0.2-omp.3

git_q -C "$work" add -A
git_q -C "$work" commit -m local-bump
rm "$work/upstream.lock.json"
(cd "$work" && bash scripts/sync.sh v0.0.2 >/dev/null)
assert "missing lock does not reset the local suffix" test "$(version)" = 0.0.2-omp.3

printf 'changed\n' >> "$up/plugins/pstack/skills/c/SKILL.md"
printf 'changed\n' >> "$up/plugins/pstack/agents/x.md"
printf 'changed\n' >> "$up/plugins/pstack/agents/comment-sicko.md"
git_q -C "$up" commit -am retag
git_q -C "$up" tag v0.0.2.1
out=$(cd "$work" && bash scripts/sync.sh v0.0.2.1)
assert "same upstream VERSION, new commit bumps the suffix" test "$(version)" = 0.0.2-omp.4
assert "changed watched file is reported to port" grep -qx 'port: plugins/pstack/agents/x.md' <<<"$out"
assert "changed verbatim agent is copied" cmp -s "$up/plugins/pstack/agents/comment-sicko.md" "$work/plugin/agents/comment-sicko.md"
assert "changed verbatim agent is not reported" test -z "$(grep 'comment-sicko' <<<"$out" || true)"

git_q -C "$work" add -A
git_q -C "$work" commit -m synced-retag
ack=$(cd "$work" && bash scripts/sync.sh --ack v0.0.2.1)
assert "ack reports the file count" test "$ack" = "acked v0.0.2.1: 1 files"
assert "ack touches only port.lock.json" test "$(git -C "$work" status --porcelain)" = ' M port.lock.json'
git_q -C "$work" add -A
git_q -C "$work" commit -m acked
out=$(cd "$work" && bash scripts/sync.sh v0.0.2.1)
assert "sync after ack reports nothing to port" test -z "$(grep '^port: ' <<<"$out" || true)"
assert "sync after ack changes nothing" test -z "$(git -C "$work" status --porcelain)"
(cd "$work" && bash scripts/sync.sh --ack v0.0.2.1 >/dev/null)
assert "ack is idempotent" test -z "$(git -C "$work" status --porcelain)"

printf 'new\n' > "$up/plugins/pstack/agents/y.md"
git_q -C "$up" add -A
git_q -C "$up" commit -m new-agent
git_q -C "$up" tag v0.0.2.2
out=$(cd "$work" && bash scripts/sync.sh v0.0.2.2)
assert "new watched file is reported" grep -qx 'port: plugins/pstack/agents/y.md' <<<"$out"
assert "unchanged recorded file is not reported" test -z "$(grep 'x.md' <<<"$out" || true)"

git_q -C "$up" rm plugins/pstack/agents/x.md plugins/pstack/agents/y.md
git_q -C "$up" commit -m drop-agent
git_q -C "$up" tag v0.0.2.3
out=$(cd "$work" && bash scripts/sync.sh v0.0.2.3)
assert "removed recorded file is reported" grep -qx 'port: plugins/pstack/agents/x.md (removed upstream)' <<<"$out"
assert "file never recorded is not reported as removed" test -z "$(grep 'y.md' <<<"$out" || true)"

git_q -C "$up" rm plugins/pstack/agents/comment-sicko.md
git_q -C "$up" commit -m drop-verbatim
git_q -C "$up" tag v0.0.2.4
out=$(cd "$work" && bash scripts/sync.sh v0.0.2.4)
assert "removed verbatim agent is reported" grep -qx 'port: plugins/pstack/agents/comment-sicko.md (removed upstream)' <<<"$out"
assert "removed verbatim agent keeps the local file" test -f "$work/plugin/agents/comment-sicko.md"

printf '0.0.3\n' > "$up/VERSION"
git_q -C "$up" commit -am three
git_q -C "$up" tag v0.0.3

for i in $(seq 4 80); do
  git_q -C "$up" tag "v0.0.$i"
done
rc=0
(cd "$work" && bash scripts/sync.sh >/dev/null 2>&1) || rc=$?
assert "auto tag selection does not fail when many tags exist" test "$rc" -eq 0
assert "auto tag selection picks the highest tag" test "$(jq -r .tag "$work/upstream.lock.json")" = v0.0.80

printf '{' > "$work/.omp-plugin/marketplace.json"
rc=0
(cd "$work" && bash scripts/sync.sh v0.0.3 >/dev/null 2>&1) || rc=$?
assert "invalid catalog fails the sync" test "$rc" -ne 0
assert "invalid catalog leaves the lock untouched" test "$(jq -r .tag "$work/upstream.lock.json")" = v0.0.80

rc=0
out=$(cd "$work" && bash scripts/sync.sh v9.9.9 2>&1) || rc=$?
assert "unknown tag fails" test "$rc" -ne 0
assert "unknown tag is named in the error" grep -q 'v9.9.9' <<<"$out"

rc=0
(cd "$work" && bash scripts/sync.sh --ack >/dev/null 2>&1) || rc=$?
assert "ack without a tag fails" test "$rc" -ne 0

if [ "$failures" -ne 0 ]; then
  echo "$failures assertion(s) failed"
  exit 1
fi
echo "all sync assertions passed"
