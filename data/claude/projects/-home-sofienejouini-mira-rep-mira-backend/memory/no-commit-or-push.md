---
name: no-commit-or-push
description: "Never git commit or push for the user, in any repo; leave changes uncommitted"
metadata:
  node_type: memory
  type: feedback
  originSessionId: f77a0a03-f00d-463d-a37c-856623b9c512
  modified: 2026-11-04T13:02:22.287Z
---

Never run `git commit` or `git push` for the user, in any of their repos (mira-*, claude-skills, …). Make the file changes, leave them uncommitted, and tell them what changed.

**Why:** The user said "only me can do it" after I committed a skill update in ~/claude-skills; they undid it.

**How to apply:** Even when asked to "update it in the repo", stop at editing files. Don't offer to commit or push. Suggest a commit message only if it's useful.
