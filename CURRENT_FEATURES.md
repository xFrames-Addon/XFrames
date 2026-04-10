# XFrames Current Features

`XFrames` is a Retail-only custom unit frame addon with a stability-first scope.

This document describes the feature set in the current stable testing version.

## Core Frame Set

- player frame
- player pet frame
- player buff row
- player debuff row
- target frame
- focus frame
- target buff row
- target-of-target frame
- focus-target frame
- micro boss frames
- party frames
- raid frames
- optional tank frames

## Live Data

The current build shows live:

- health values and bars
- power values and bars
- level text
- class-colored names where applicable
- player specialization text
- target and focus specialization text when inspect data is available

## Party And Performance Display

Party frames support two subtitle modes:

- status mode
- DPS mode

When `Show DPS` is enabled:

- player subtitle switches to DPS or HPS
- party subtitles switch to DPS or HPS based on role
- player and party frames attempt to show Blizzard-native meter rank when available

## Cast Bars

The current build includes:

- player cast bar
- target cast bar
- movable cast bars while frames are unlocked
- spell name display on cast bars

Current cast bars are intentionally conservative for Retail safety:

- they show cast state and spell name
- they use Blizzard-safe duration objects where available
- they do not currently use protected interruptibility values

## Frame Interaction

The current unit frames support:

- left-click targeting
- right-click unit menu where Blizzard allows it
- tooltips on hover
- movable layouts while unlocked
- saved frame positions

## Visual Options

The current build supports:

- live portraits
- class icon mode for player units
- class-colored portrait borders
- class or unit-colored outer frame accents

## Blizzard Frame Controls

The settings panel and slash commands can control:

- Blizzard unit frame visibility
- Blizzard cast bar visibility
- Blizzard raid frame restoration when custom raid frames are disabled
- frame locking and unlocking
- portrait mode
- buff bar visibility
- DPS display mode
- reload UI

## Settings Panel

The settings panel currently supports:

- dragging the panel out of the way
- saved panel position
- wrapped help text and option labels

## Party Preview

When frames are unlocked and you are not in a real party:

- party frames enter a built-in demo mode
- preview members show names, roles, portraits or class icons, and bars

This makes layout work possible without needing a live group.

## Raid Support

The current test build includes:

- compact raid frames
- ready check icons
- dead-state dimming and `DEAD` overlays
- role icons
- greyed out-of-range styling
- optional raid tank frames
- micro boss frames

Raid frames are still the newest part of the addon and are the main area still under active polish.

## Diagnostics

The addon includes built-in diagnostics:

- slash-command debug controls
- optional CVar helpers
- internal log buffer in saved variables

## Current Limits

Known intentional limits in the current stable build:

- raid and tank frames still need more live-raid testing
- interruptibility coloring is disabled because the current Retail client treats that path as protected in addon code
- rank display may still depend on what Blizzard exposes for native meter identity in a given encounter
- buff rows are currently only implemented for player and target
