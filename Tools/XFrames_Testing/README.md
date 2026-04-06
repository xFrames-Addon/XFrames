# XFrames Testing

`XFrames_Testing` is a development-only addon for detached preview and simulation utilities.

## Purpose

- keep simulation and preview logic out of the shipping `XFrames` addon
- allow party and raid test tools to evolve separately from live frame code
- make it easy to omit testing utilities from public releases

## Planned Scope

- drive synthetic party and raid roster data through narrow `XFrames` preview hooks
- force preview layouts without needing a real group or raid
- stay removable without changing the shipping addon

## Current Commands

- `/xftest status`
- `/xftest party on`
- `/xftest party off`
- `/xftest raid on [count]`
- `/xftest raid off`
- `/xftest clear`

## Packaging Note

This folder is intentionally kept under `Tools/` so it is not part of the live addon load path in the main project tree.

To use it in-game, it should be copied or packaged as its own top-level addon folder:

- `XFrames`
- `XFrames_Testing`
