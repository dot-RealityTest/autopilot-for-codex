# Codex Automation Menu

Tiny macOS menu bar control surface for local Codex automations.

It reads:

- `~/.codex/automations/*/automation.toml`
- `~/.codex/automations/*/memory.md`

The menu bar popover is the fast surface: live status, review hints, and one-step actions.

The control window is for lightweight inspection: overview, recent actions, approval permissions, affected areas, and proposed changes.

Actions:

- Open Codex
- Open Control window
- Review an automation in Codex
- Open the local automation folder
- Refresh
- Quit

Icon colors:

- Green: automations look active
- Orange: approval-style guardrails are present
- Red: attention is needed
- Gray: no active automations

Run:

```sh
./scripts/build-app.sh
open "dist/Codex Automation Menu.app"
```
