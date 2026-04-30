# XFrames Continuity

This document is the starting point for resuming `XFrames` work on a new machine or in a new Codex thread.

## Current Working Reality

- Main active repo: `XFrames`
- Current active branch: `codex/raid-frames`
- Secondary repo: `CDB`
- `CDB` is currently paused
- The unit-frame project is the active focus

## Current Branch Status

The `codex/raid-frames` branch is the live working branch for ongoing development and debugging.

As of this document:

- player, target, focus, target-of-target, focus-target, player pet, and party frames are active
- raid, tank, and boss work has been heavily iterated and is currently being narrowed and stabilized
- the branch has a recent protected-frame visibility hardening pass

## Repos To Keep

1. `XFrames`
2. `CDB`

Only `XFrames` is currently expected to move forward immediately.

## Start Here On A New Machine

1. Clone or open the existing `XFrames` repo.
2. Check out `codex/raid-frames`.
3. Read:
   - `README.md`
   - `CURRENT_FEATURES.md`
   - `ROADMAP.md`
   - `MIDNIGHT_RULES.md`
   - `LEARNED_BEHAVIORS.md`
   - `DEBUGGING_WORKFLOW.md`
4. Pull latest changes before testing.
5. Treat live test errors as the source of truth.

## Current Priority

The current priority is not feature expansion. It is:

- stabilizing unit frames under Midnight rules
- reducing chat-frame addon issue reports
- keeping secure-frame and protected-UI interactions conservative

## CDB Status

`CDB` is paused because live cooldown timing has repeatedly crossed into protected-value behavior. It may be revisited later if Blizzard exposes a safer cooldown-manager companion path.

## Working Principle

When in doubt:

- trust live test reports over theory
- prefer display-only behavior over “smart” combat logic
- avoid touching protected values if there is any sign Blizzard treats them as secret

