# Upstream port v0.9.139..v0.9.157 (2026-11-26)

## Decisions

- **Port on top of the sync, one PR.** The branch carries the plain `scripts/sync.sh v0.9.157` commit (identical to sync PR #44) and the hand port after it, so `scripts/check.sh` sees rules and skills from the same tag. #44 becomes redundant; the next sync run finds no diff and closes it. Rejected: porting on `main` first, because a rule that names v0.9.157 panels would contradict the v0.9.138 skills still on `main`.
- **`comment-sicko`:** take upstream's body verbatim; it never differed from upstream.
- **`omp-tools.md` rows ported into `rule://pstack-omp-tools`:** the `verify` lookup order (`.omp/skills/` → `.claude/skills/` → `.agents/skills/`), project and personal skill destinations for the verification, formal verification and `automate-me` skills, and `reflect`'s copy destinations. Rejected: letting skills read `omp-tools.md` again, because its model section forbids the pinned agents this fork exists for.
- **Panels are `arena` and `interrogate` only.** Upstream 0.9.140 turned `architect` into a short brief and made `how`, `why` and `reflect` single-subagent skills. The routing rule no longer lists panels by name; the one list lives in `rule://pstack-omp-tools`.
- **Dropped the `pstack:poteto-agent-<level>` / `pstack:effort-<level>` row.** No v0.9.157 skill names those forms. Its effort mapping moved to the model-alias row.
- **Not ported:** `CLAUDE_CODE_REMOTE` cloud-session REST fallbacks, Pi and DeepSeek sheet rows, `SessionStart` hook prompts. None applies to OMP.

## Sync robustness (same day)

- **Why #44 stalled:** port detection diffed upstream from `upstream.lock.json`'s commit, which moves only when the sync PR merges. A port on `main` could not clear the hold, so every hold needed a hand merge.
- **`port.lock.json` records what was ported:** the upstream tag and the blob of each hand-ported file. `scripts/sync.sh` prints `port:` for a blob that differs or a file that is new or gone; `scripts/sync.sh --ack <tag>` records a port. A push to `main` that changes it reruns the sync. Rejected: a `ported_commit` field diffed like before, because it needs a fetch of an old commit (the old `port: unknown` failure) and cannot ack one file. Rejected: auto-merging skills while ports wait in an issue, because it reverses #42's hold, which the user chose.
- **`comment-sicko` syncs verbatim.** It has no OMP edits, so it left the port set.
- **`scripts/check.sh` now compares** the panel list in `rule://pstack-omp-tools` with the one upstream generates into `codex-tools.md`, and the model-pinned agents' bodies with their base. Both drifted or could drift silently before. The `poteto-agent-<level>` / `effort-<level>` allowance is gone, so a skill naming those forms fails the gate.
