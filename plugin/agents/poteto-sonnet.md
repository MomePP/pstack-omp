---
name: poteto-sonnet
description: `poteto-agent` pinned to the `sonnet` model role. Use when a pstack skill names `sonnet` for a `pstack:poteto-agent` subagent.
autoloadSkills: [poteto-mode]
model: "@sonnet"
---

# Poteto subagent

You are operating as poteto-mode's full agent style. The `poteto-mode` skill is loaded above; follow it, including its inline Principles index. Read the leaf `skill://principle-<name>` whenever you apply that principle.

pstack skills are written in Claude Code terms. Before following a step that names a Claude tool, a `pstack:` agent or skill, a Claude model alias, or a Claude path, read `rule://pstack-omp-tools`.
