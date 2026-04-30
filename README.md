# XFrames

`XFrames` is a fresh Retail-only World of Warcraft unit frame addon.

It replaces the legacy ZPerl salvage approach with a clean rebuild that:

- avoids Blizzard frame takeover patterns
- keeps module boundaries small and explicit
- prioritizes Retail safety and maintainability over feature parity

## Current Scope

The current test build includes:

- player frame
- player buff and debuff rows
- player cast bar
- target frame
- focus frame
- micro boss frames
- target-of-target
- focus-target
- player pet
- party frames
- raid frames
- optional tank frames
- a small modern options surface

## Testing Module

A separate development scaffold for future simulation work lives under:

- `Tools/XFrames_Testing/`

That code is intentionally decoupled from the live addon so party and raid test tools can stay removable.

## Design Rules

- Retail only
- no split-addon architecture
- no disabling or reparening Blizzard-managed frames
- no legacy XML-heavy options system unless there is a clear need
- prefer small Lua modules with explicit lifecycle hooks

## Diagnostics

Built-in debugging is part of the core design.

See:

- `DEBUGGING.md`

## Continuity Docs

For moving between machines or resuming work in a new Codex session, start with:

- `CONTINUITY.md`
- `MIDNIGHT_RULES.md`
- `LEARNED_BEHAVIORS.md`
- `DEBUGGING_WORKFLOW.md`
