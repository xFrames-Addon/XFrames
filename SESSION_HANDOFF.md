# XFrames Session Handoff

## Current State

`XFrames` is a brand-new Retail-only addon scaffold created to replace the failing ZPerl salvage effort.

The project intentionally starts with:

- one addon folder
- one `.toc`
- one saved-variable table
- a small module registration system
- built-in diagnostic mode with saved log buffering and debug slash commands

## Intentional Non-Goals Right Now

- no attempt at ZPerl feature parity
- no Blizzard frame disabling
- no Blizzard frame reparening
- no raid implementation yet

## Next Best Step

Build the first real frame path:

1. player frame shell
2. target frame shell
3. target-of-target shell
4. player pet shell

Raid frames come later after the core patterns are proven.

## Debugging

Use:

- `/xframes status`
- `/xframes debug on`
- `/xframes debug dump`
- `/xframes debug clear`

When debug is enabled, the addon attempts to turn on `scriptErrors` and `taintLog` and also keeps its own rolling diagnostic log in saved variables.
