# Debugging Workflow

This is the workflow that has worked best on this project.

## Core Rule

Use live test evidence to guide changes.

Do not do broad speculative rewrites unless a whole subsystem is proven bad.

## Testing Loop

1. Pull latest branch on the test machine.
2. Reproduce with the smallest setup possible.
3. Capture:
   - exact visible behavior
   - whether the issue appears on login, `/reload`, combat start, boss pull, etc.
   - any `Errors.txt`, `Error_Report.txt`, `taint.log`, screenshots, or notes
4. Push those artifacts to the repo.
5. Patch only the failing path.

## Best Artifact Types

Best to capture:

- `Errors.txt`
- `Error_Report.txt`
- screenshots
- short repro notes

Useful but less direct:

- generic “addon caused an issue” counts without a stack

## Debugging Priorities

When an issue is vague:

1. secure-frame visibility code
2. inspect paths
3. Blizzard frame visibility and state drivers
4. live combat value formatting and comparisons
5. meter integrations

## Branch Guidance

Current development branch:

- `codex/raid-frames`

Do feature and taint work there first unless there is a specific reason to work elsewhere.

## What To Avoid

- trying many unrelated fixes at once
- reintroducing old known-risk paths “just to try”
- assuming a Blizzard-displayed value is addon-safe

