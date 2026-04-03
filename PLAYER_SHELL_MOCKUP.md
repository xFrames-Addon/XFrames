# XFrames Player Shell Mockup

## Goals

The first player shell should prove the core architecture without recreating old ZPerl complexity.

Version 1 should:

- create one standalone player frame
- show name, level, portrait, health bar, and power bar
- support move/lock later without requiring it immediately
- avoid Blizzard frame takeover patterns
- be easy to debug and extend

## Mockup

```text
+------------------------------------------------------+
| [Portrait]  Player Name                    Lv 80     |
|            Class / status text                        |
|------------------------------------------------------|
| Health                                   823k / 900k |
| [======================================  ]      91%  |
|------------------------------------------------------|
| Mana                                     210k / 250k |
| [=================================       ]      84%  |
+------------------------------------------------------+
```

## Frame Pieces

### Top Row

- portrait on the left
- player name centered-left
- level on the right
- optional short status text under the name

### Middle Row

- health bar
- numeric health text
- health percent text

### Bottom Row

- power bar
- numeric power text
- power percent text

## First Build Scope

Included:

- root frame creation
- player portrait texture
- player name
- player level
- health updates
- power updates
- basic coloring
- basic show and refresh behavior

Not included yet:

- buffs
- cast bar
- class resources
- alternate power
- combat feedback
- vehicle handling
- pet integration
- drag/lock UI
- options panel

## Suggested Module Shape

`Modules/Player/XFrames_Player.lua` should own:

- frame creation
- event registration for player updates
- a single `Refresh` path
- a few small update helpers:
  - `UpdateName`
  - `UpdateLevel`
  - `UpdatePortrait`
  - `UpdateHealth`
  - `UpdatePower`

## Initial Sizing

- width: about `240`
- height: about `74`
- portrait width: about `48`
- bar height: about `16`

These numbers are just a starting point and should be easy to adjust.

## Styling Direction

Keep it simple and intentional:

- dark neutral backdrop
- muted borders
- green health bar
- blue power bar
- readable white text
- no heavy ornament yet

## Why This First

If this shell loads cleanly, updates correctly, and stays stable, it gives us:

- a known-good event/update pattern
- a reusable bar/text layout
- a real baseline for target and pet frames

That is a much better foundation than starting with a feature-dense player frame.
