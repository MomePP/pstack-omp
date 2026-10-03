---
description: pstack routing for OMP
alwaysApply: true
---

You have pstack.

- Read `skill://poteto-mode` and follow it when a task touches more than one file or changes a signature other files call, involves a design or architecture choice, or is a bug whose cause is not yet known or a performance issue. It routes to the right pstack skill from there. For smaller tasks (a contained change to one file with an obvious test, a question, a one-line edit), work directly and verify on the real artifact.
- When the intent is already specific, enter that skill directly: `skill://tdd`, `skill://architect`, `skill://how`, `skill://why`, `skill://arena`, `skill://interrogate`.
- pstack skills are written in Claude Code terms. These translations always apply:
  - `Agent` tool → `task`; N parallel agents = one `task` call with N `tasks[]` items. `subagent_type: "pstack:poteto-agent"` → `agent: "poteto-agent"`; `"pstack:comment-sicko"` → `agent: "comment-sicko"`; `general-purpose` → the default `task` agent.
  - When a skill names a model for a subagent (`opus`, `fable`, `sonnet`, `haiku`, optionally with an effort level), set that task item's `model` to `"@opus"`, `"@fable"`, `"@sonnet"`, or `"@haiku"` (with `:<level>` when given). Never drop it: multi-model panels (`arena`, `architect`, `interrogate`, `how`, `why`, `reflect`) depend on each reviewer running on its own model.
  - `Skill` tool or `pstack:<skill>` → `read skill://<skill>`. `AskUserQuestion` → `ask`. `TaskCreate`/`TaskUpdate`/`TodoWrite` → `todo`.
  - For anything else Claude-specific (`readonly`, `isolation`, `SendMessage`, `ScheduleWakeup`, `/loop`, `~/.claude/…` paths, `CLAUDE.md`, `run`/`verify`), read `rule://pstack-omp-tools` before following the step.
- Ignore `skill://poteto-mode/references/pi-tools.md` and `skill://poteto-mode/references/codex-tools.md`. OMP is neither Pi nor Codex; its tools differ from both.
- User instructions (AGENTS.md, direct requests) take precedence over pstack.
