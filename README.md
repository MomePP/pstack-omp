# pstack-omp

> **Personal use.** This is my own port of pstack to [oh-my-pi (OMP)](https://github.com/can1357/oh-my-pi), tuned for my setup. It is public because the license allows it and because public marketplaces install without credentials. No support, no roadmap; fork it if it helps you.

[pstack](https://github.com/cursor/plugins/tree/main/pstack) is Lauren Tan's ([poteto](https://x.com/poteto)) skill stack for rigorous agent work: `poteto-mode`, its playbooks, the principle leaves, multi-model review panels, and `unslop`. [pstack-claude](https://github.com/michael-denyer/pstack-claude) by Michael Denyer translates it from Cursor to Claude Code. This repo carries pstack-claude's skills **unmodified** and adds the small OMP layer they need.

## What is in it

| Path | What | Who writes it |
|---|---|---|
| `plugin/skills/` | the pstack skills | `scripts/sync.sh` only, copied verbatim from a pstack-claude release tag |
| `plugin/rules/pstack-routing.md` | always-apply rule: route multi-file, design, and unknown-cause bug work through `poteto-mode` | hand-written |
| `plugin/rules/pstack-omp-tools.md` | `rule://pstack-omp-tools`: Claude Code → OMP mapping (`Agent` → `task`, `AskUserQuestion` → `ask`, model aliases, paths) | hand-written |
| `plugin/agents/` | `poteto-agent` (preloads `poteto-mode`) and `comment-sicko` | hand-written / upstream body |
| `upstream.lock.json` | the pstack-claude tag and commit the skills came from | `scripts/sync.sh` |
| `upstream-licenses/` | upstream license and notice files | `scripts/sync.sh` |

There is no runtime extension. The skills stay in Claude Code language, and the mapping rule translates them while they run. Because nobody edits the skill files, syncing is a plain copy and never conflicts.

## Install

```sh
omp plugin marketplace add MomePP/pstack-omp
omp plugin install pstack@pstack-omp
```

Start a new session afterwards. Check with:

```sh
omp -p --no-session "Do not call tools. List the agents in the task tool's Available Agents."
```

`poteto-agent` and `comment-sicko` should be listed.

### Model roles

The skills name models by alias (`opus`, `fable`, `sonnet`, `haiku`). Bind roles with those exact names in `~/.omp/agent/config.yml` so `model: "@fable"` resolves:

```yaml
modelRoles:
  opus: anthropic/claude-opus-5-5:high
  fable: anthropic/claude-fable-5-1:high
  sonnet: anthropic/claude-sonnet-5-5:medium
  haiku: anthropic/claude-haiku-4-5:low
```

Point them at whatever you have. The panel skills (`arena`, `architect`, `interrogate`) run three models per call. They cost about three times a single-model review, and they stay diverse only while the aliases resolve to different models.

### Using it

The routing rule applies on its own. To force it, type `/skill:poteto-mode <task>`, or enter a specific skill such as `/skill:how`, `/skill:why`, or `/skill:interrogate`.

Your own instructions (`~/.omp/agent/AGENTS.md`) win over pstack. I use that to keep push, PR creation, and merging behind a confirmation.

### Turning it off

`omp plugin disable pstack@pstack-omp`, or keep the skills and drop only the routing by listing the rule in `disabledExtensions` (find its id with `/extensions`).

## Sync

`.github/workflows/sync.yml` runs daily. When pstack-claude has a newer `v*` tag, it runs `scripts/sync.sh` and `scripts/check.sh`, then opens one PR on `sync/pstack-claude` with the gate result and the added and removed skills. When the gate passes, the workflow enables GitHub auto-merge (squash) on that PR, and GitHub merges it once the required `check` status passes. When the gate fails, the PR stays open as a draft for review. A failing `check`, a conflict, or a refused auto-merge also leaves the PR open.

This relies on two repository settings: **Allow auto-merge** and **Automatically delete head branches** (Settings → General), and a `main` branch ruleset that requires the `check` status from GitHub Actions, with Repository admin in its bypass list.

The PR is opened with the `SYNC_TOKEN` secret: a fine-grained personal access token for this repository only, with **Contents** and **Pull requests** set to read and write. A PR opened with the workflow's own `GITHUB_TOKEN` does not start `check` until a maintainer approves the run, so it would never merge on its own. Without the secret, the workflow falls back to `GITHUB_TOKEN` and each sync PR waits for that approval. When the token expires, the PR step fails and the run goes red; renew the token and update the secret.

Every run rebuilds `sync/pstack-claude` from `main`, so a commit pushed to that branch is lost on the next run. When the gate fails, put the fix (a new agent, a mapping row) on `main`, then rerun the workflow (`gh workflow run sync.yml`); the PR updates, turns green, and merges.

`scripts/check.sh` fails when there are no skills, a skill lacks `name` or `description`, a skill spawns a `pstack:` agent this plugin does not ship or map, a `pstack:<skill>` reference has no skill, a rule or agent points at a missing `skill://<name>` or `autoloadSkills` entry, or the catalog or lock is invalid JSON or the catalog has no version.

Versions read `<pstack-claude version>-omp.<n>`. A sync to a new upstream version resets `<n>` to 1; a new upstream commit under the same version increments it. Bump `<n>` in `.omp-plugin/marketplace.json` by hand for local changes. `omp plugin upgrade` only notices a changed catalog version:

```sh
omp plugin marketplace update pstack-omp
omp plugin upgrade pstack@pstack-omp
```

Run the sync locally with `scripts/sync.sh [tag]`, and the tests with `bash tests/check.test.sh && bash tests/sync.test.sh`.

## Credits and license

pstack © 2026 Lauren Tan; cursor-team-kit skills © 2026 Cursor; pstack-claude port © 2026 Michael Denyer. All MIT. Their license and notice files are in `upstream-licenses/`. The OMP layer here is MIT, see `LICENSE`.
