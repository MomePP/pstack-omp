# pstack-omp

> **Personal use.** This is my own port of pstack to [oh-my-pi (OMP)](https://github.com/can1357/oh-my-pi), tuned for my setup. It is public because the license allows it and because public marketplaces install without credentials. No support, no roadmap; fork it if it helps you.

[pstack](https://github.com/cursor/plugins/tree/main/pstack) is Lauren Tan's ([poteto](https://x.com/poteto)) skill stack for rigorous agent work: `poteto-mode`, its playbooks, the principle leaves, multi-model review panels, and `unslop`. [pstack-claude](https://github.com/michael-denyer/pstack-claude) by Michael Denyer translates it from Cursor to Claude Code. This repo carries pstack-claude's skills **unmodified** and adds the small OMP layer they need.

## What is in it

| Path | What | Who writes it |
|---|---|---|
| `plugin/skills/` | the pstack skills | `scripts/sync.sh` only, copied verbatim from a pstack-claude release tag |
| `plugin/rules/pstack-routing.md` | always-apply rule: route multi-file, design, and unknown-cause bug work through `poteto-mode` | hand-written |
| `plugin/rules/pstack-omp-tools.md` | `rule://pstack-omp-tools`: Claude Code → OMP mapping (`Agent` → `task`, `AskUserQuestion` → `ask`, model aliases, paths) | hand-written |
| `plugin/agents/` | `poteto-agent` (preloads `poteto-mode`), its model-pinned copies, `comment-sicko`, and the two thermo-nuclear review subagents (preload their rubric skills) | hand-written / upstream body; `comment-sicko` is copied verbatim by `scripts/sync.sh` |
| `upstream.lock.json` | the pstack-claude tag and commit the skills came from | `scripts/sync.sh` |
| `port.lock.json` | the upstream tag and blob of each hand-ported file, as last ported | `scripts/sync.sh --ack` |
| `upstream-licenses/` | upstream license and notice files | `scripts/sync.sh` |

There is no runtime extension. The skills stay in Claude Code language, and the mapping rule translates them while they run. Because nobody edits the skill files, syncing is a plain copy and never conflicts. The skills' own OMP mapping (`poteto-mode/references/omp-tools.md`) targets a different install; the routing rule overrides it.

## Install

```sh
omp plugin marketplace add MomePP/pstack-omp
omp plugin install pstack@pstack-omp
```

Start a new session afterwards. Check with:

```sh
omp -p --no-session "Do not call tools. List the agents in the task tool's Available Agents."
```

`poteto-agent`, `comment-sicko`, `thermo-nuclear-review-subagent`, `thermo-nuclear-code-quality-review-subagent`, and the model-pinned `task-{opus,sonnet,haiku}` and `poteto-{opus,sonnet,haiku}` should be listed.

### Model roles

The skills name models by alias (`opus`, `fable`, `sonnet`, `haiku`). OMP's `task` tool has no per-item `model` field since 18.8.2, so the plugin ships one agent per alias (`task-<alias>`, `poteto-<alias>`, each with `model: "@<alias>"`) and the rules route a named model to it. `fable` is the exception: it has no pinned agent, so its single role (poteto-mode's `strongest judgment`) runs on the `opus` agent at the highest effort, and the panels drop its seat. Bind roles with those exact names in `~/.omp/agent/config.yml`:

```yaml
modelRoles:
  opus: anthropic/claude-opus-5-5:medium
  sonnet: anthropic/claude-sonnet-5-5:high
  haiku: anthropic/claude-haiku-5-5:high
task:
  enableEffort: true
  maxEffort: xhigh
```

The suffix is the effort a subagent starts at when the parent passes no `effort`. With `enableEffort`, the parent can pass `lo`, `med` or `hi`, which pick the model's lowest, middle and highest level (`low`, `high`, `max` on a five-level model), capped at `maxEffort`.

Point them at whatever you have. The panel skills (`arena`, `interrogate`) run one model per bound alias. They cost about that many times a single-model review, and they stay diverse only while the aliases resolve to different models.

### Using it

The routing rule applies on its own. To force it, type `/skill:poteto-mode <task>`, or enter a specific skill such as `/skill:how`, `/skill:why`, or `/skill:interrogate`.

Your own instructions (`~/.omp/agent/AGENTS.md`) win over pstack. I use that to keep push, PR creation, and merging behind a confirmation.

### Turning it off

`omp plugin disable pstack@pstack-omp`, or keep the skills and drop only the routing by adding `rule:pstack-routing` to `disabledExtensions`.

## Sync

`.github/workflows/sync.yml` runs daily at 19:00 UTC; GitHub often starts scheduled runs hours late. It runs `scripts/sync.sh` and `scripts/check.sh` against the newest `v*` tag of pstack-claude, then opens one PR on `sync/pstack-claude` with the gate result, the added and removed skills, and a `port:` line for each upstream file this repo ports by hand (an agent under `plugins/pstack/agents/`, the OMP extension, `omp-tools.md`) whose blob differs from `port.lock.json`. When the gate passes, the workflow marks the PR ready if an earlier run left it as a draft. With no `port:` line it enables GitHub auto-merge (squash), and GitHub merges the PR once the required `check` status passes. With a `port:` line it leaves auto-merge off and links the upstream compare from the last ported tag. When the gate fails, the PR stays open as a draft for review. A failing `check`, a conflict, or a refused auto-merge also leaves the PR open.

To clear `port:` lines, port the change, run `scripts/sync.sh --ack <tag>`, and commit `port.lock.json` with the port. A push to `main` that changes `port.lock.json` reruns the sync, which then finds nothing to port and arms auto-merge. A port that only makes sense with the new skills (a mapping row for a skill the sync adds, a panel list that `scripts/check.sh` compares with the synced skills) fails the gate on `main` by itself; put it in one PR on top of `scripts/sync.sh <tag>` instead. Once that PR merges, the next run finds no diff and closes the sync PR.

This relies on two repository settings: **Allow auto-merge** and **Automatically delete head branches** (Settings → General), and a `main` branch ruleset that requires the `check` status from GitHub Actions, with Repository admin in its bypass list.

The PR is opened with the `SYNC_TOKEN` secret: a fine-grained personal access token for this repository only, with **Contents** and **Pull requests** set to read and write. A PR opened with the workflow's own `GITHUB_TOKEN` does not start `check` until a maintainer approves the run, so it would never merge on its own. Without the secret, the workflow falls back to `GITHUB_TOKEN` and each sync PR waits for that approval. When the token expires, the PR step fails and the run goes red; renew the token and update the secret.

Every run rebuilds `sync/pstack-claude` from `main`, so a commit pushed to that branch is lost on the next run. When the gate fails, put the fix (a new agent, a mapping row) on `main`, or in one PR with the sync as above, then rerun the workflow (`gh workflow run sync.yml`) if no push started it.

`scripts/check.sh` fails when there are no skills, a skill lacks `name` or `description`, a skill spawns a `pstack:` agent this plugin does not ship, a `pstack:<skill>` reference has no skill, a skill points OMP at a mapping file the routing rule does not override, a rule or agent points at a missing `skill://<name>` or `autoloadSkills` entry, a model-pinned agent's body differs from its base agent, the panel list in `rule://pstack-omp-tools` differs from the one upstream generates into `codex-tools.md`, or the catalog or a lock is invalid JSON or the catalog has no version.

Versions read `<pstack-claude version>-omp.<n>`. A sync to a new upstream version resets `<n>` to 1; a new upstream commit under the same version increments it. Bump `<n>` in `.omp-plugin/marketplace.json` by hand for local changes. `omp plugin upgrade` only notices a changed catalog version:

```sh
omp plugin marketplace update pstack-omp
omp plugin upgrade pstack@pstack-omp
```

Run the sync locally with `scripts/sync.sh [tag]`, and the tests with `bash tests/check.test.sh && bash tests/sync.test.sh`.

## Credits and license

pstack © 2026 Lauren Tan; cursor-team-kit skills © 2026 Cursor; pstack-claude port © 2026 Michael Denyer. All MIT. Their license and notice files are in `upstream-licenses/`. The OMP layer here is MIT, see `LICENSE`.
