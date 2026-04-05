# XFrames Architecture

## Goals

- build a stable Retail-native frame addon from scratch
- keep secure behavior narrow and predictable
- separate core lifecycle from individual frame modules

## Layout

- `XFrames.toc`: addon manifest
- `Core/`: addon namespace, defaults, lifecycle, and shared helpers
- `Modules/Player/`: player-frame module
- `Modules/Target/`: target and target-of-target module
- `Modules/Raid/`: future raid-frame module
- `Tools/XFrames_Testing/`: separate development-only addon scaffold for future simulation tools

## Core Principles

1. The core owns startup, saved variables, and module registration.
2. Modules register themselves and expose `Initialize` and optional `Enable`.
3. Blizzard-managed UI stays under Blizzard control.
4. New frame code should prefer fresh frame construction over adapting legacy frame trees.
5. Raid support is deferred until the core player/target path is stable in live testing.
6. Testing and simulation utilities should live outside the shipping addon whenever practical.
