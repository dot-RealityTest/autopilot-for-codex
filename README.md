# Codex Automation Menu

Tiny macOS menu bar helper for local Codex automations.

It reads:

- `~/.codex/automations/*/automation.toml`
- `~/.codex/automations/*/memory.md`

The menu bar popover is a fast report: status counts, lightweight row status, and actions.

The full report window has the richer summary: approval hints, schedules, model info, newest memory highlights, smallest next steps, and a quieter inspector for key changes.

Actions:

- Open Codex
- Open Full Report window
- Review a `Needs OK` automation in Codex
- Open the local automation folder
- Refresh
- Quit

Icon colors:

- Green: automations look active
- Orange: approval-style guardrails are present
- Red: latest memory suggests a blocker
- Gray: no active automations

Run:

```sh
./scripts/build-app.sh
open "dist/Codex Automation Menu.app"
```
