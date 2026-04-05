# XFrames Session Handoff

Last updated: 2026-04-05 on the Windows testing machine.

## Shared Chat Workflow

This repo now doubles as a simple handoff bridge between Codex chats on different machines.

Start here, then check:

- `HANDOFF_PROTOCOL.md`
- `handoff/TESTING_LOG.md`
- `handoff/QUESTIONS_FOR_OTHER_CHAT.md`

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

## Latest Shared Note

The Windows testing chat initialized a repo-backed handoff workflow so pasted test output, bug notes, and questions can be committed and pulled by the Mac implementation chat.

## Debugging

Use:

- `/xframes status`
- `/xframes debug on`
- `/xframes debug dump`
- `/xframes debug clear`

When debug is enabled, the addon attempts to turn on `scriptErrors` and `taintLog` and also keeps its own rolling diagnostic log in saved variables.
