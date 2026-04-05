# XFrames Handoff Protocol

This repo can be used as a shared mailbox between Codex chats on different machines.

## Shared Files

- `SESSION_HANDOFF.md`: the current project snapshot and first file to read.
- `handoff/TESTING_LOG.md`: append raw testing notes, slash-command output, errors, and reproduction steps.
- `handoff/QUESTIONS_FOR_OTHER_CHAT.md`: leave explicit asks, decisions, and answers for the other chat.

## Recommended Flow

1. Paste notes, errors, or observations into whichever Codex chat you are using.
2. Ask that chat to record the note in the appropriate handoff file.
3. Commit and push the change so the other machine can pull it.
4. The other chat reads `SESSION_HANDOFF.md` first, then the detailed handoff files.

## What Goes Where

- Use `SESSION_HANDOFF.md` for the current status, priorities, and high-level direction.
- Use `handoff/TESTING_LOG.md` for append-only raw evidence and test results.
- Use `handoff/QUESTIONS_FOR_OTHER_CHAT.md` for direct requests like "please inspect this error" or "this behavior is now fixed."

## Entry Style

Keep entries short and structured:

- timestamp
- machine or chat source
- branch if known
- area under test
- observed behavior
- expected behavior
- next ask or recommendation

## Working Agreement

- The testing-machine chat owns recording fresh observations quickly and accurately.
- The implementation chat owns resolving or replying to open questions and updating the high-level session summary.
- Either chat may update any handoff file, but should preserve existing notes unless they are clearly superseded.
