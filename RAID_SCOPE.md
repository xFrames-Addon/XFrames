# Raid Frames Scope

This document defines the scope for raid-frame work on the `codex/raid-frames` branch.

## Goal

Build fresh Retail-safe raid frames for `XFrames` without reintroducing the unstable patterns that broke the old addon base.

## Non-Goals

Do not add:

- Blizzard raid-frame takeover logic
- legacy secure-header hacks from older addons
- old split-addon architecture
- XML-heavy feature creep
- raid modules that depend on protected combat-state paths we cannot support safely

## First Raid Milestone

The first milestone should focus on a minimal shell:

- raid member frame layout
- secure click targeting/menu support where allowed
- health and power display
- name and level display
- class-colored accents
- movable raid anchor while unlocked
- saved layout position

## Second Raid Milestone

After the shell is stable:

- role indicators
- optional DPS/HPS subtitle support using the same native meter model as party frames
- tooltip support
- cleaner spacing and readability work

## Testing Rules

Raid work should be validated with:

- live grouped testing when available
- the removable testing addon under `Tools/XFrames_Testing`
- isolated bug fixes on the raid branch until stable

## Safety Rules

Raid implementation should follow the same safety posture as the stable branch:

- prefer simple event-driven updates
- avoid Lua-side logic on protected or secret values
- remove unsafe features rather than forcing them through
- keep shared helpers in `Core` when they are broadly reusable

## Merge Standard

Raid work should not merge back to `main` until:

- frames load without taint on Retail
- group and raid joins are stable
- unlocking and moving raid layouts works cleanly
- Blizzard raid tools remain usable unless we intentionally replace them
- the feature set is testable by other users without special setup
