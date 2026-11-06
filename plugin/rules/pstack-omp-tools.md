---
description: Claude Code → OMP mapping for pstack skills; read before following a step that names a Claude tool, pstack agent or skill, model alias, or Claude path
---

# pstack on OMP

pstack skills name Claude Code tools, agents, models, and paths. On OMP use these equivalents. Every other instruction in the skill stands as written.

| pstack / Claude Code | OMP |
|---|---|
| `Skill` tool, `pstack:<skill>`, `/<skill>` | `read skill://<skill>`; the user types `/skill:<skill>`. If the returned `[Skill file: …]` path is outside the pstack plugin, read the `skill://<namespace>/<skill>` copy the skill list shows for pstack |
| `Agent` / `Task` tool with `subagent_type: "pstack:poteto-agent"` | `task` with `agent: "poteto-agent"`. N parallel agents = one `task` call with N `tasks[]` items |
| `subagent_type: "pstack:comment-sicko"` | `task` with `agent: "comment-sicko"`; pass the scope; no isolation, because it needs the uncommitted changes |
| `subagent_type: "pstack:thermo-nuclear-review-subagent"`, `"pstack:thermo-nuclear-code-quality-review-subagent"` | `task` with `agent: "thermo-nuclear-review-subagent"` or `agent: "thermo-nuclear-code-quality-review-subagent"`; `thermos` runs both in one `tasks[]` batch |
| `pstack:poteto-agent-<level>`, `pstack:effort-<level>` | `agent: "poteto-agent"` or the default `task` agent, with the item's `effort` set from `<level>` (`low` → `"lo"`, `medium` → `"med"`, `high`/`xhigh`/`max` → `"hi"`) when the `task` tool offers it |
| `general-purpose`, `Explore`, `Plan` | the default `task` agent; `scout` for read-only exploration; `task-<alias>` when the skill names a model |
| `readonly: true` | say "do not edit files" in the task; prefer a read-only agent (`scout`, `reviewer`) where it fits |
| `run_in_background: true` | OMP tasks run asynchronously and their results arrive on their own; never poll |
| `SendMessage` to a running agent | `write agent://<id>` |
| `isolation: "worktree"` | the `task` tool's isolation option when it offers one; otherwise give each writing worker its own output directory |
| `AskUserQuestion` | `ask` |
| `TaskCreate` / `TaskUpdate` / `TodoWrite`, the `todo.md` fallback | `todo` (always available on OMP; never write `todo.md`). A playbook step's `skip: <reason>` = `drop` the step and state the reason in the same turn |
| `ScheduleWakeup` | an `async` `bash` job (`sleep <seconds>`) whose completion wakes you; never sleep-poll |
| `/loop`, the `loop` skill | to pace your own re-checks, the `ScheduleWakeup` row; for a prompt the user wants repeated, give them OMP's interactive `/loop [count\|duration] [--while\|--until '<command>'] [prompt]` line to type |
| `WebSearch`, `WebFetch` | `web_search`; `read <url>` for a known page |
| `~/.claude/projects/<encoded-cwd>/` transcripts | `~/.omp/agent/sessions/<encoded-cwd>/` session files; `history://<id>` for registered agents |
| `run`, the project `verify` skill | run the program directly and observe its output; drive a web UI with the session's browser tools; a project verify skill lives at `.omp/skills/verify/` |
| `plugin-dev:skill-development` | OMP skill conventions: `skills/<name>/SKILL.md` with `name` and `description` frontmatter |
| `CLAUDE.md`, "your instructions file" | `~/.omp/agent/AGENTS.md` (user), `.omp/AGENTS.md` or `AGENTS.md` (project) |
| model aliases `opus`, `fable`, `sonnet`, `haiku` on a subagent | the agent pinned to that alias: `task-<alias>` for `general-purpose`, `poteto-<alias>` for `pstack:poteto-agent`. `task` has no per-item `model` field (removed in OMP 18.8.2). Each pinned agent runs on the same-named `modelRoles` entry |
| `setup-pstack`, the `pstack-models.md` sheet | bind the `opus`, `fable`, `sonnet`, `haiku` roles under `modelRoles` in `~/.omp/agent/config.yml`, using only models `omp models` lists and keeping every other key. Routing on or off is `omp plugin disable pstack@pstack-omp`, or the routing rule's id in `disabledExtensions` |

- The `recall` and `reflect` skills are pstack workflows, not OMP's memory tools of the same names.
- Read `skill://typescript-best-practices` before editing `*.ts` or `*.tsx` files. Upstream loads it through `paths:` frontmatter, which OMP does not honor.
- Diverse-model panels (`arena`, `architect`, `interrogate`) stay diverse only while their aliases resolve to different models. If a role is unbound or several aliases point at one model, say in the verdict that diversity was reduced.
