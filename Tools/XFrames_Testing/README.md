# XFrames Testing

`XFrames_Testing` is a development-only addon scaffold for future test utilities.

## Purpose

- keep simulation and preview logic out of the shipping `XFrames` addon
- allow party and raid test tools to evolve separately from live frame code
- make it easy to omit testing utilities from public releases

## Planned Scope

- spawn preview layouts for party and raid frames
- drive fake roster data for visual layout testing
- expose dev-only slash commands and helper toggles
- stay removable without changing `XFrames`

## Packaging Note

This folder is intentionally kept under `Tools/` so it is not part of the live addon load path in the main project tree.

When we are ready to use it in-game, it can be copied or packaged as its own top-level addon folder:

- `XFrames`
- `XFrames_Testing`
