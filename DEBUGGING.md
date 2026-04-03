# XFrames Debugging

## Goals

`XFrames` ships with a built-in diagnostic mode so troubleshooting does not depend on manual console prep every time.

## Slash Commands

- `/xframes status`
- `/xframes debug on`
- `/xframes debug off`
- `/xframes debug toggle`
- `/xframes debug status`
- `/xframes debug cvars`
- `/xframes debug dump`
- `/xframes debug dump 50`
- `/xframes debug clear`

## What Debug Mode Does

- enables internal addon logging to the saved variables ring buffer
- attempts to set `scriptErrors=1`
- attempts to set `taintLog=5`
- prints warnings and errors to chat

## Limits

- secure CVars cannot be changed in combat
- some CVar behavior may still require `/reload` or logout to persist fully
- `taint.log` remains a Blizzard client log file, not an addon-owned file

## Saved Data

Diagnostic entries are stored in:

- `XFramesDB.profile.diagnostics.logs`

The log buffer is capped so it does not grow forever.
