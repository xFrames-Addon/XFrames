# Midnight Rules

This file captures the working rules for `XFrames` under Midnight-era Retail behavior.

These rules are based on both:

- Blizzard's published Midnight addon philosophy
- live testing against the client

Official references:

- [Midnight: Get up to Speed with User Interface Updates](https://worldofwarcraft.blizzard.com/en-us/news/24223311)
- [How Midnight’s Upcoming Game Changes Will Impact Combat Addons](https://worldofwarcraft.blizzard.com/news/24244638/how-midnights-upcoming-game-changes-will-impact-combat-addons)
- [Combat Philosophy and Addon Disarmament in Midnight](https://worldofwarcraft.blizzard.com/en-gb/news/24246290)
- [Midnight Pre-Expansion Content Update Notes](https://worldofwarcraft.blizzard.com/en-us/news/24244455)

## High-Level Rule

Addons may still change presentation, layout, size, positioning, and visual emphasis.

Addons should not rely on being able to inspect, compare, or derive meaning from protected live combat values.

## Safe Direction

Generally safe or safer in this project:

- custom unit-frame presentation
- buffs and debuffs as display elements
- frame movement and layout out of combat
- role icons, ready check icons, dead indicators
- display-only use of visible state
- Blizzard-owned duration objects when available
- Blizzard native meter text when handled conservatively

## Unsafe Direction

Historically unsafe or confirmed risky in this project:

- direct comparisons on secret values
- math on protected combat values
- formatting logic that depends on protected values
- reconstructing cooldowns from live remaining time
- branching on interruptibility
- branching on threat values or threat status in some contexts
- direct show/hide changes on protected frames during combat
- state-driver changes during combat
- direct GUID equality checks in inspect-ready paths

## Project Rules

These are the project-specific rules that should guide all new code:

1. Never assume a value is safe because Blizzard displays it.
2. Avoid comparing, sorting, dividing, abbreviating, or thresholding combat values unless proven safe.
3. Prefer display-only outputs over derived logic.
4. Defer protected frame visibility changes until after combat.
5. Do not mutate Blizzard UI visibility from combat-driven refresh events.
6. Prefer queued, deferred, or cached data over live inspection during combat.
7. If a path has already caused taint once, do not reintroduce it casually.

## XFrames-Specific Guidance

- secure unit buttons are allowed, but their visibility handling must stay conservative
- inspect flows should prefer pending-unit context over comparing event GUID payloads
- cast bars should prefer Blizzard-safe duration objects over local time math
- party and raid style indicators should be visual, not decision-making systems

## CDB-Specific Guidance

`CDB` is currently paused because cooldown timing repeatedly crossed into protected behavior.

If revisited later:

- prefer Blizzard cooldown-manager companion behavior
- avoid live cooldown-duration inspection
- avoid local combat-timer reconstruction unless a safe source exists

