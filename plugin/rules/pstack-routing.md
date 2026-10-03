---
description: pstack routing for OMP
alwaysApply: true
---

You have pstack.

- Read `skill://poteto-mode` and follow it when a task touches more than one file or changes a signature other files call, involves a design or architecture choice, or is a bug whose cause is not yet known or a performance issue. It routes to the right pstack skill from there. For smaller tasks (a contained change to one file with an obvious test, a question, a one-line edit), work directly and verify on the real artifact.
- When the intent is already specific, enter that skill directly: `skill://tdd`, `skill://architect`, `skill://how`, `skill://why`, `skill://arena`, `skill://interrogate`.
- pstack skills are written in Claude Code terms. Before following a step that names a Claude tool (`Agent`, `Skill`, `AskUserQuestion`, `TaskCreate`, `ScheduleWakeup`, `SendMessage`), a `pstack:` agent or skill, a Claude model alias (`opus`, `fable`, `sonnet`, `haiku`), or a Claude path (`~/.claude/…`, `CLAUDE.md`), read `rule://pstack-omp-tools`.
- Ignore `skill://poteto-mode/references/pi-tools.md` and `skill://poteto-mode/references/codex-tools.md`. OMP is neither Pi nor Codex; its tools differ from both.
- User instructions (AGENTS.md, direct requests) take precedence over pstack.
