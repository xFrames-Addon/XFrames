# Testing Log

Add the newest entry at the top.

## Template

### YYYY-MM-DD HH:MM TZ - Short Title
- Source:
- Branch:
- Area:
- Steps:
- Observed:
- Expected:
- Artifacts:
- Follow-up:

### 2026-04-05 12:03 America/Los_Angeles - Party-style unit frame screenshot captured
- Source: Windows testing chat
- Branch: main
- Area: live frame rendering
- Steps: User pasted a screenshot from the testing machine into the Windows Codex chat for repo handoff.
- Observed: The screenshot shows four stacked unit frames for `Captain Garrick`, `Crenna Earth-Daughter`, `Austin Huxworth`, and `Shuja Grimaxe`, each with portrait, yellow name text, level `90`, green health bar text, and blue power bar text visible.
- Expected: Screenshot should be available to the Mac coding session as a testing artifact reference.
- Artifacts: `Screenshot 2026-04-05 131034.jpg`
- Follow-up: Mac coding chat should review the screenshot from git and compare the live rendering against expected party frame behavior.

### 2026-04-05 11:45 America/Los_Angeles - Handoff workflow initialized
- Source: Windows testing chat
- Branch: main
- Area: repo process
- Steps: Added shared handoff docs and templates to the repo.
- Observed: The repo now has a standard place for pasted test notes and cross-chat questions.
- Expected: The Mac chat can pull these files and continue from the same shared context.
- Artifacts: `HANDOFF_PROTOCOL.md`, `SESSION_HANDOFF.md`, `handoff/QUESTIONS_FOR_OTHER_CHAT.md`
- Follow-up: Record future pasted test output here and commit it for the other machine.
