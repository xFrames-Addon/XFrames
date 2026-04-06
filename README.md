# XFrames

`XFrames` is a fresh Retail-only World of Warcraft unit frame addon.

It replaces the legacy ZPerl salvage approach with a clean rebuild that:

- avoids Blizzard frame takeover patterns
- keeps module boundaries small and explicit
- prioritizes Retail safety and maintainability over feature parity

## Initial Scope

The first build targets:

- player frame
- target frame
- target-of-target
- player pet
- a small modern options surface

Raid frames are planned, but they will be built fresh after the core frame architecture is stable.

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

