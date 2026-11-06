# OMP mapping precedence (2026-11-06)

## Decisions

- **Keep pstack-omp; do not switch to the skills' bundled OMP plugin layer.** That layer has no model-pinned agents, so multi-model panels (`arena`, `architect`, `interrogate`, `how`, `why`, `reflect`) would run every reviewer on one model. The user picked this option. Rejected: archiving now, or keeping only the pinned agents as user-level agents next to the bundled layer, because its `omp-tools.md` forbids model aliases and would contradict them on every run.
- **`rule://pstack-omp-tools` is the only OMP mapping.** The routing rule ignores `omp-tools.md` and every other platform mapping. `scripts/check.sh` fails when a skill points OMP at a file the routing rule does not name in backticks.
- **Ported:** `WebSearch`/`WebFetch`, `/loop` as a user command, `setup-pstack` mapped to `modelRoles`, a fallback for a skill name taken by another source, browser tools for web UIs, and coexistence with other session-start mandates.
- **Fixed:** `create_heartbeat` does not exist on OMP 18.16.0. `ScheduleWakeup` is an async `bash` `sleep` job with `timeout` set above the sleep.
- **Not ported:** a runtime extension for a `session hook: off` toggle (`rule:pstack-routing` in `disabledExtensions` already does this), and reading skills by absolute path (a `skill://` fallback covers collisions).
