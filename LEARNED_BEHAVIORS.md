# Learned Behaviors

This file records what we have learned from repeated live testing.

It is intentionally practical.

## Confirmed Safe Or Safer Patterns

### 1. Display beats derivation

Showing a visual state is often fine.

Trying to derive meaning from that state is where trouble starts.

Examples:

- buff and debuff icons: workable
- frame dead overlays: workable
- ready check icons: workable
- role icons: workable

### 2. Duration-object paths are better than local math

For cast bars, the safer path was:

- use Blizzard duration objects where possible
- avoid reading raw start and end times
- avoid custom countdown math in combat

### 3. Secure frames need deferred visibility handling

Direct `Show()` and `Hide()` on secure unit frames from live refresh code is risky.

Safer pattern:

- defer protected frame visibility updates until after combat
- allow regular refresh logic to update text and bars, but not force visibility changes in combat

### 4. Blizzard visibility control should be centralized

Frame-hiding logic should run from a central helper, not ad hoc from module event code.

### 5. Testing reports matter more than assumptions

The client repeatedly proved that values we expected to be safe were not.

## Confirmed Unsafe Or Risky Patterns

### 1. Inspect GUID comparisons

Directly comparing event GUID payloads in inspect-ready flows caused trouble.

Safer approach:

- queue inspect requests
- keep pending unit and pending GUID locally
- consume the pending unit on response

### 2. Live cooldown duration reads

Cooldown timing repeatedly tainted in `CDB`.

We should not assume live cooldown `duration` is safe just because Blizzard can show it.

### 3. Threat-state logic

Threat-related values looked promising but did not remain safe enough in our frame context.

Aggro indicator work is deferred.

### 4. Interruptibility state

Interruptibility-related values were not stable enough for addon logic in our tests.

Interrupt color behavior was intentionally removed.

### 5. Range checks

Some range-related checks crossed into protected behavior.

Keep range display coarse and conservative.

## Active XFrames Hotspots To Treat Carefully

- `Core/XFrames_UI.lua`
- `Modules/Party/XFrames_Party.lua`
- `Modules/Target/XFrames_Target.lua`
- any code that touches:
  - secure unit buttons
  - inspect
  - Blizzard frame visibility
  - live combat meter values

## Current Working Heuristic

If a feature requires any of the following, stop and test very narrowly before expanding:

- comparison
- math
- string coercion
- ranking
- sorting
- thresholding
- combat-state inference

